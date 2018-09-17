# frozen_string_literal: true

require 'anycable/socket'

module Anycable
  # RPC service handler
  class RPCHandler 
    def handle(data)
      request = JSON.parse(data)
      #binding.pry
      case request['command']
      when "connect"
        connect(request)
      when "disconnect"
      when "perform", "subscribe", "unsubscribe"
        perform(request)
      end
    end
    # Handle connection request from WebSocket server
    def connect(request)
      logger.debug("RPC Connect: #{request}")

      socket = build_socket(env: rack_env(request))
      connection = factory.call(socket)
      
      connection.handle_open
      if socket.closed?
        Anycable.to_client.write({
          "ws_id" => request["ws_id"],
          "command" => request["command"],
          "status" => "failure"
        }.to_json)
      else

        Anycable.to_client.write({
          "ws_id" => request["ws_id"],
          "command" => request["command"],
          "status" => "success",
          "identifiers" => connection.identifiers_json,
          "transmissions" => socket.transmissions
        }.to_json)
      end
    end

    def disconnect(request)
      logger.debug("RPC Disonnect: #{request}")

      socket = build_socket(env: rack_env(request))

      connection = factory.call(
        socket,
        identifiers: request.identifiers,
        subscriptions: request.subscriptions
      )

      if connection.handle_close
        Anycable::DisconnectResponse.new(status: Anycable::Status::SUCCESS)
      else
        Anycable::DisconnectResponse.new(status: Anycable::Status::FAILURE)
      end
    end

    def perform(message)
      logger.debug("RPC Command: #{message}")
      msg = JSON.load(message["message"])
      socket = build_socket(env: rack_env(message))

      connection = factory.call(
        socket,
        identifiers: msg["identifier"]
      )
      message["command"] = "message" if message["command"] == "perform"
      begin
        #binding.pry
        connection.connect

      rescue ActionCable::Connection::Authorization::UnauthorizedError => e

        Anycable.to_client.write({
          "ws_id"         => message["ws_id"],
          "command"       => "perform",
          "status"        => "failure",
          "disconnect"    => true,
          "stop_streams"  => true,
          "streams"       => [],
          "identifiers"   => nil,
          "transmissions" => []
        }.to_json)
        return
      end
      result = connection.handle_channel_command(
        msg["identifier"],
        message["command"],
        msg["data"]
      )

      Anycable.to_client.write({
        "ws_id"         => message["ws_id"],
        "command"       => message["command"],
        "status"        => result ? "success" : "failure",
        "disconnect"    => socket.closed?,
        "stop_streams"  => socket.stop_streams?,
        "streams"       => socket.streams,
        "identifiers"   => msg["identifier"],
        "transmissions" => socket.transmissions
      }.to_json)
    end

    private

    # Build env from path
    def rack_env(request)
      uri = URI.parse(request['path'])
      {
        'QUERY_STRING' => uri.query,
        'SCRIPT_NAME' => '',
        'PATH_INFO' => uri.path,
        'SERVER_PORT' => uri.port.to_s,
        'HTTP_HOST' => uri.host,
        # Hack to avoid Missing rack.input error
        'rack.request.form_input' => '',
        'rack.input' => '',
        'rack.request.form_hash' => {}
      }.merge(build_headers(request['headers']))
    end

    def build_socket(**options)
      Anycable::Socket.new(**options)
    end

    def build_headers(headers)
      headers.each_with_object({}) do |(k, v), obj|
        k = k.upcase
        k.tr!('-', '_')
        obj["HTTP_#{k}"] = v
      end
    end

    def logger
      Anycable.logger
    end

    def factory
      Anycable.connection_factory
    end
  end
end
