# frozen_string_literal: true

require "json"
require "jwt"

module MudisWebCache
  module Auth
    module_function

    def required?(segments)
      return false unless Env.jwt_enabled?
      return false if segments.first == "health"
      return false if segments.first == "docs"
      return false if segments.first == "openapi.json"

      true
    end

    def authenticate(req, segments)
      return nil unless required?(segments)

      secret = Env.jwt_secret
      return error(500, "jwt secret not configured") if secret.nil? || secret.empty?

      token = bearer_token(req)
      return error(401, "missing bearer token") if token.nil?

      claims = decode_token(token, secret)
      return error(401, "invalid token") if claims.nil?

      if admin_request?(req, segments) && !admin_claim?(claims)
        return error(403, "admin token required")
      end

      req.env["mudis.jwt.claims"] = claims
      nil
    rescue JWT::ExpiredSignature
      error(401, "token expired")
    rescue JWT::DecodeError
      error(401, "invalid token")
    rescue StandardError
      error(500, "authentication error")
    end

    def admin_request?(req, segments)
      return true if segments.first == "reset" && req.post?
      return true if segments.first == "metrics" && req.post? && segments[1] == "reset"
      return true if segments.first == "namespace" && req.delete?

      false
    end

    def admin_claim?(claims)
      claim_name = Env.jwt_admin_claim
      expected = Env.jwt_admin_value

      value = claims[claim_name] || claims[claim_name.to_sym]

      return true if value == true
      return value.to_s == expected if value.is_a?(String) || value.is_a?(Symbol)
      return value.include?(expected) if value.is_a?(Array)

      false
    end

    def decode_token(token, secret)
      options = { algorithm: Env.jwt_algorithm }
      issuer = Env.jwt_issuer
      audience = Env.jwt_audience

      if issuer
        options[:iss] = issuer
        options[:verify_iss] = true
      end

      if audience
        options[:aud] = audience
        options[:verify_aud] = true
      end

      payload, _header = JWT.decode(token, secret, true, options)
      payload
    end

    def bearer_token(req)
      header = req.get_header("HTTP_AUTHORIZATION").to_s
      return nil if header.empty?

      scheme, token = header.split(/\s+/, 2)
      return nil unless scheme&.casecmp("bearer")&.zero?

      token&.strip
    end

    def error(status, message)
      body = JSON.dump(error: message)
      [status, { "Content-Type" => "application/json", "Content-Length" => body.bytesize.to_s }, [body]]
    end
  end
end
