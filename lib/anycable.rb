# frozen_string_literal: true

require "anycable/version"
require "anycable/config"
require "logger"

# Anycable allows to use any websocket service (written in any language) as a replacement
# for ActionCable server.
#
# Anycable includes a gRPC server, which is used by external WS server to execute commands
# (authentication, subscription authorization, client-to-server messages).
#
# Broadcasting messages to WS is done through Redis Pub/Sub.
module Anycable
  class << self
    # Provide connection factory which
    # is a callable object with build
    # a Connection object
    attr_accessor :connection_factory

    def logger=(logger)
      @logger = logger
    end

    def logger
      return @logger if instance_variable_defined?(:@logger)
      log_output = Anycable.config.log_file || STDOUT
      @logger = Logger.new(log_output).tap do |logger|
        logger.level = Anycable.config.log_level
      end
    end

    def config
      @config ||= Config.new
    end

    def to_client
      return @to_client if @to_client
      
      cfg = {topic: config.to_client_topic}
      if config.to_client_lookupd
        cfg[:nsqlookupd] = config.to_client_lookupd
      else
        cfg[:nsqd] = config.to_client_nsqd
      end
      @to_client ||= Nsq::Producer.new(cfg)
    end

    def from_client
      return @from_client if @from_client
      
      cfg = {
        topic: config.from_client_topic, 
        channel: config.from_client_channel, 
        msg_timeout: config.from_client_msg_timeout, 
        max_in_flight: config.from_client_max_in_flight
      }
      if config.from_client_lookupd
        cfg[:nsqlookupd] = config.from_client_lookupd
      else
        cfg[:nsqd] = config.from_client_nsqd
      end
      @from_client ||= Nsq::Consumer.new(cfg)
    end

    def configure
      yield(config) if block_given?
    end

    def error_handlers
      return @error_handlers if instance_variable_defined?(:@error_handlers)
      @error_handlers = []
    end

    def pubsub
      @pubsub ||= PubSub.new
    end

    # Broadcast message to the channel
    def broadcast(channel, payload)
      pubsub.broadcast(channel, payload)
    end
  end
end

require "anycable/server"
require "anycable/pubsub"
