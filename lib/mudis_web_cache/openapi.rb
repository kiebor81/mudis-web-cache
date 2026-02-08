# frozen_string_literal: true

module MudisWebCache
  module OpenAPI
    module_function

    def spec(base_url = nil)
      {
        openapi: "3.0.3",
        info: {
          title: "Mudis Web Cache API",
          version: "1.0.0"
        },
        servers: servers(base_url),
        paths: paths
      }
    end

    def servers(base_url)
      return [] unless base_url

      [{ url: base_url }]
    end

    def paths
      {
        "/health" => {
          get: {
            summary: "Health check",
            responses: json_response(200)
          }
        },
        "/metrics" => {
          get: {
            summary: "Get cache metrics",
            responses: json_response(200)
          }
        },
        "/metrics/reset" => {
          post: {
            summary: "Reset cache metrics",
            responses: json_response(200)
          }
        },
        "/reset" => {
          post: {
            summary: "Reset cache data",
            responses: json_response(200)
          }
        },
        "/cache/{key}" => {
          get: {
            summary: "Read a cache key",
            parameters: [path_key_param, namespace_param],
            responses: json_response(200)
          },
          post: {
            summary: "Write a cache key",
            parameters: [path_key_param, namespace_param],
            requestBody: json_body_schema(write_body_schema),
            responses: json_response(200)
          },
          put: {
            summary: "Write a cache key",
            parameters: [path_key_param, namespace_param],
            requestBody: json_body_schema(write_body_schema),
            responses: json_response(200)
          },
          delete: {
            summary: "Delete a cache key",
            parameters: [path_key_param, namespace_param],
            responses: json_response(200)
          }
        },
        "/cache/{key}/inspect" => {
          get: {
            summary: "Inspect cache key metadata",
            parameters: [path_key_param, namespace_param],
            responses: json_response(200)
          }
        },
        "/exists/{key}" => {
          get: {
            summary: "Check if key exists",
            parameters: [path_key_param, namespace_param],
            responses: json_response(200)
          }
        },
        "/keys" => {
          get: {
            summary: "List keys in a namespace",
            parameters: [namespace_param],
            responses: json_response(200)
          }
        },
        "/namespace/{namespace}" => {
          delete: {
            summary: "Clear a namespace",
            parameters: [path_namespace_param],
            responses: json_response(200)
          }
        },
        "/least-touched" => {
          get: {
            summary: "List least-touched keys",
            parameters: [count_param],
            responses: json_response(200)
          }
        },
        "/ql" => {
          post: {
            summary: "Run a Mudis-QL query",
            requestBody: json_body_schema(ql_body_schema),
            responses: json_response(200)
          }
        }
      }
    end

    def json_response(status)
      {
        status => {
          description: "OK",
          content: {
            "application/json" => {
              schema: { type: "object" }
            }
          }
        }
      }
    end

    def json_body_schema(schema)
      {
        required: true,
        content: {
          "application/json" => { schema: schema }
        }
      }
    end

    def path_key_param
      {
        name: "key",
        in: "path",
        required: true,
        schema: { type: "string" }
      }
    end

    def path_namespace_param
      {
        name: "namespace",
        in: "path",
        required: true,
        schema: { type: "string" }
      }
    end

    def namespace_param
      {
        name: "namespace",
        in: "query",
        required: false,
        schema: { type: "string" }
      }
    end

    def count_param
      {
        name: "count",
        in: "query",
        required: false,
        schema: { type: "integer", minimum: 1 }
      }
    end

    def write_body_schema
      {
        type: "object",
        properties: {
          value: { description: "Value to store", nullable: true },
          expires_in: { type: "integer", description: "TTL in seconds", nullable: true },
          namespace: { type: "string", nullable: true }
        },
        required: ["value"]
      }
    end

    def ql_body_schema
      {
        type: "object",
        properties: {
          namespace: { type: "string", nullable: true },
          where: { type: "object", nullable: true },
          order: { type: "object", nullable: true },
          limit: { type: "integer", nullable: true },
          offset: { type: "integer", nullable: true },
          action: { type: "string", nullable: true },
          fields: { type: "array", items: { type: "string" }, nullable: true },
          field: { type: "string", nullable: true }
        }
      }
    end
  end
end
