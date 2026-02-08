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

    def string(name, default: nil)
      val = ENV[name]
      return default if val.nil? || val.strip.empty?

      val
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

    def jwt_enabled?
      bool("MUDIS_JWT_ENABLED", default: true)
    end

    def jwt_secret
      string("MUDIS_JWT_SECRET")
    end

    def jwt_algorithm
      string("MUDIS_JWT_ALGORITHM", default: "HS256")
    end

    def jwt_issuer
      string("MUDIS_JWT_ISSUER")
    end

    def jwt_audience
      string("MUDIS_JWT_AUDIENCE")
    end

    def jwt_admin_claim
      string("MUDIS_JWT_ADMIN_CLAIM", default: "role")
    end

    def jwt_admin_value
      string("MUDIS_JWT_ADMIN_VALUE", default: "admin")
    end

    def bind_enabled?
      bool("MUDIS_BIND_ENABLED", default: false)
    end

    def bind_namespace_claim
      string("MUDIS_BIND_NAMESPACE_CLAIM", default: "sub")
    end

    def bind_prefix
      string("MUDIS_BIND_PREFIX", default: "")
    end
  end
end
