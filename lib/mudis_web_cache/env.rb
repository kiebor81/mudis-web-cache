# frozen_string_literal: true

require "json"

module MudisWebCache
  module Env
    module_function

    def bool(name, default: false)
      val = ENV[name]
      return default if val.nil? || val.strip.empty?

      case val.strip.downcase
      when "1", "true", "yes", "on"
        true
      when "0", "false", "no", "off"
        false
      else
        default
      end
    end

    def int(name, default: nil)
      val = ENV[name]
      return default if val.nil? || val.strip.empty?

      Integer(val)
    rescue ArgumentError
      default
    end

    def float(name, default: nil)
      val = ENV[name]
      return default if val.nil? || val.strip.empty?

      Float(val)
    rescue ArgumentError
      default
    end

    def serializer
      value = ENV.fetch("MUDIS_SERIALIZER", "json").strip.downcase
      case value
      when "json"
        JSON
      when "marshal"
        Marshal
      when "oj"
        require "oj"
        Oj
      else
        JSON
      end
    end

    def persistence_format
      ENV.fetch("MUDIS_PERSISTENCE_FORMAT", "json").strip.downcase.to_sym
    end

    def expiry_interval
      int("MUDIS_EXPIRY_INTERVAL", default: 60)
    end
  end
end
