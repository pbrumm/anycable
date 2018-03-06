# frozen_string_literal: true

require "redis"
require "json"

module Anycable
  # PubSub for broadcasting
  class PubSub
    attr_reader :redis_conn


    def initialize
      Anycable.to_client
    end

    def broadcast(channel, payload)
      Anycable.to_client.write({ stream: channel, data: payload }.to_json)
    end
  end
end
