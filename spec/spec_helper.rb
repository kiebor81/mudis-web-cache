# frozen_string_literal: true

require "rack/test"
require "json"
require "jwt"

require_relative "../lib/mudis_web_cache"

RSpec.configure do |config|
  config.include Rack::Test::Methods

  config.before do
    Mudis.reset!
    Mudis.reset_metrics!
  end

  config.around do |example|
    original = ENV.to_hash
    example.run
  ensure
    ENV.clear
    original.each { |k, v| ENV[k] = v }
  end
end

def app
  MudisWebCache::App.new
end

def json_body
  JSON.parse(last_response.body)
end

def jwt_token(payload, secret: "test-secret", algorithm: "HS256")
  JWT.encode(payload, secret, algorithm)
end
