# frozen_string_literal: true

require "json"
require "rack"
require "mudis"
require "mudis-ql"
require_relative "openapi"

module MudisWebCache
  class App
    def call(env)
      req = Rack::Request.new(env)
      segments = path_segments(req.path_info)

      case segments
      when []
        return json(200, name: "mudis-web-cache", status: "ok") if req.get?
      end

      if segments.first == "health" && req.get?
        return json(200, status: "ok")
      end

      if segments.first == "openapi.json" && req.get?
        spec = MudisWebCache::OpenAPI.spec(base_url(req))
        return json(200, spec)
      end

      if segments.first == "docs" && req.get?
        return swagger_ui(req)
      end

      if segments.first == "metrics"
        return handle_metrics(req, segments)
      end

      if segments.first == "reset" && req.post?
        Mudis.reset!
        return json(200, status: "reset")
      end

      if segments.first == "cache"
        return handle_cache(req, segments)
      end

      if segments.first == "exists"
        return handle_exists(req, segments)
      end

      if segments.first == "inspect"
        return handle_inspect(req, segments)
      end

      if segments.first == "keys" && req.get?
        return handle_keys(req)
      end

      if segments.first == "namespace"
        return handle_namespace(req, segments)
      end

      if segments.first == "least-touched" && req.get?
        return handle_least_touched(req)
      end

      if segments.first == "ql" && req.post?
        return handle_ql(req)
      end

      json(404, error: "not found")
    rescue ArgumentError => e
      json(400, error: e.message)
    rescue StandardError => e
      json(500, error: e.message)
    end

    private

    def handle_metrics(req, segments)
      if req.get? && segments.length == 1
        return json(200, Mudis.metrics)
      end

      if req.post? && segments[1] == "reset"
        Mudis.reset_metrics!
        return json(200, status: "metrics_reset")
      end

      json(404, error: "not found")
    end

    def handle_cache(req, segments)
      key = segments[1]
      return json(400, error: "key is required") unless key

      if req.get? && segments.length == 2
        namespace = req.params["namespace"]
        value = Mudis.read(key, namespace: namespace)
        return json(404, error: "not found") if value.nil?

        return json(200, value: value)
      end

      if (req.post? || req.put?) && segments.length == 2
        params = merged_params(req)
        namespace = params["namespace"]
        expires_in = to_int(params["expires_in"])
        value = params.key?("value") ? params["value"] : nil

        return json(400, error: "value is required") if value.nil?

        Mudis.write(key, value, expires_in: expires_in, namespace: namespace)
        return json(200, status: "written", key: key)
      end

      if req.delete? && segments.length == 2
        namespace = req.params["namespace"]
        Mudis.delete(key, namespace: namespace)
        return json(200, status: "deleted", key: key)
      end

      if req.get? && segments[2] == "inspect"
        namespace = req.params["namespace"]
        data = Mudis.inspect(key, namespace: namespace)
        return json(404, error: "not found") if data.nil?

        return json(200, data)
      end

      json(404, error: "not found")
    end

    def handle_exists(req, segments)
      key = segments[1]
      return json(400, error: "key is required") unless key

      namespace = req.params["namespace"]
      json(200, exists: Mudis.exists?(key, namespace: namespace))
    end

    def handle_inspect(req, segments)
      key = segments[1]
      return json(400, error: "key is required") unless key

      namespace = req.params["namespace"]
      data = Mudis.inspect(key, namespace: namespace)
      return json(404, error: "not found") if data.nil?

      json(200, data)
    end

    def handle_keys(req)
      namespace = req.params["namespace"]
      return json(400, error: "namespace is required") if namespace.nil? || namespace.empty?

      json(200, keys: Mudis.keys(namespace: namespace))
    end

    def handle_namespace(req, segments)
      namespace = segments[1]
      return json(400, error: "namespace is required") unless namespace

      if req.delete?
        Mudis.clear_namespace(namespace: namespace)
        return json(200, status: "cleared", namespace: namespace)
      end

      json(404, error: "not found")
    end

    def handle_least_touched(req)
      count = to_int(req.params["count"]) || 10
      json(200, keys: Mudis.least_touched(count))
    end

    def handle_ql(req)
      params = merged_params(req)
      namespace = params["namespace"]
      action = (params["action"] || "all").to_s

      scope = MudisQL.from(namespace)
      scope = apply_where(scope, params["where"]) if params["where"]
      scope = apply_order(scope, params["order"]) if params["order"]
      scope = scope.limit(to_int(params["limit"])) if params["limit"]
      scope = scope.offset(to_int(params["offset"])) if params["offset"]

      result = execute_action(scope, action, params)
      json(200, result: result)
    end

    def apply_where(scope, where)
      return scope unless where.is_a?(Hash)

      converted = {}
      where.each do |field, condition|
        converted[field] = parse_condition(condition)
      end

      scope.where(converted)
    end

    def apply_order(scope, order)
      return scope if order.nil?

      if order.is_a?(Hash)
        field = order["field"] || order[:field]
        direction = order["direction"] || order[:direction] || :asc
        return scope.order(field, direction.to_sym)
      end

      scope.order(order)
    end

    def execute_action(scope, action, params)
      case action
      when "all"
        scope.all
      when "first"
        scope.first
      when "last"
        scope.last
      when "count"
        scope.count
      when "exists"
        scope.exists?
      when "pluck"
        fields = Array(params["fields"]) + Array(params[:fields])
        scope.pluck(*fields)
      when "sum"
        field = params["field"] || params[:field]
        scope.sum(field)
      when "average"
        field = params["field"] || params[:field]
        scope.average(field)
      when "group_by"
        field = params["field"] || params[:field]
        scope.group_by(field)
      else
        raise ArgumentError, "unknown action: #{action}"
      end
    end

    def parse_condition(condition)
      return condition unless condition.is_a?(Hash)

      if condition.key?("regex")
        pattern = condition["regex"].to_s
        flags = condition["flags"].to_s
        opts = 0
        opts |= Regexp::IGNORECASE if flags.include?("i")
        opts |= Regexp::MULTILINE if flags.include?("m")
        opts |= Regexp::EXTENDED if flags.include?("x")
        return Regexp.new(pattern, opts)
      end

      if condition.key?("range")
        range = condition["range"]
        if range.is_a?(Array) && range.length == 2
          return range[0]..range[1]
        end
        if range.is_a?(Hash)
          min = range["min"] || range[:min]
          max = range["max"] || range[:max]
          inclusive = range.key?("inclusive") ? range["inclusive"] : true
          return inclusive ? (min..max) : (min...max)
        end
      end

      if condition.key?("in")
        values = Array(condition["in"])
        return ->(v) { values.include?(v) }
      end

      condition
    end

    def merged_params(req)
      params = req.params.dup
      body = read_json(req)
      params.merge!(body) if body
      params
    end

    def read_json(req)
      return nil unless req.media_type == "application/json"

      body = req.body.read
      return nil if body.nil? || body.strip.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      raise ArgumentError, "invalid JSON body"
    ensure
      req.body.rewind
    end

    def json(status, payload)
      body = JSON.dump(payload)
      [status, { "Content-Type" => "application/json", "Content-Length" => body.bytesize.to_s }, [body]]
    end

    def swagger_ui(req)
      html = <<~HTML
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Mudis Web Cache API</title>
          <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
        </head>
        <body>
          <div id="swagger-ui"></div>
          <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
          <script>
            window.ui = SwaggerUIBundle({
              url: "#{base_url(req)}/openapi.json",
              dom_id: "#swagger-ui"
            });
          </script>
        </body>
        </html>
      HTML
      [200, { "Content-Type" => "text/html; charset=utf-8", "Content-Length" => html.bytesize.to_s }, [html]]
    end

    def base_url(req)
      scheme = req.env["HTTP_X_FORWARDED_PROTO"] || req.scheme
      host = req.env["HTTP_X_FORWARDED_HOST"] || req.host
      port = req.env["HTTP_X_FORWARDED_PORT"] || req.port
      default_port = (scheme == "https" ? 443 : 80)
      port_part = port.to_i == default_port ? "" : ":#{port}"
      "#{scheme}://#{host}#{port_part}"
    end

    def path_segments(path)
      Rack::Utils.unescape_path(path.to_s).split("/").reject(&:empty?)
    end

    def to_int(value)
      return nil if value.nil? || value == ""

      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
