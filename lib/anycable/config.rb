# frozen_string_literal: true

require "anyway_config"

module Anycable
  # Anycable configuration.
  class Config < Anyway::Config
    config_name :anycable

    attr_config to_client_topic: "ws_fromrails",
                to_client_nsqd: "localhost:4150",
                to_client_lookupd: nil,

                from_client_topic: "ws_fromclient",
                from_client_channel: "rails",
                from_client_nsqd: "localhost:4150",
                from_client_lookupd: nil,
                from_client_msg_timeout: 5000,
                from_client_max_in_flight: 5,
                
                log_file: nil,
                log_level: :info,
                log_grpc: false,
                debug: false # Shortcut to enable GRPC logging and debug level

    def initialize(*)
      super
      # Set log params if debug is true
      return unless debug
      self.log_level = :debug
      self.log_grpc = true
    end
  end
end
