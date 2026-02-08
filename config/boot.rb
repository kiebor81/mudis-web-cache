# frozen_string_literal: true

require "bundler/setup"

require "mudis"
require "mudis_server"
require "mudis_client"
require "mudis-ql"

require_relative "../lib/mudis_web_cache/env"
require_relative "../lib/mudis_web_cache/ipc_extensions"

module MudisWebCache
  module Boot
    module_function

    def configure_mudis!
      Mudis.configure do |c|
        c.serializer = Env.serializer
        c.compress = Env.bool("MUDIS_COMPRESS", default: c.compress)

        if (val = Env.int("MUDIS_MAX_VALUE_BYTES"))
          c.max_value_bytes = val
        end

        c.hard_memory_limit = Env.bool("MUDIS_HARD_MEMORY_LIMIT", default: c.hard_memory_limit)

        if (val = Env.int("MUDIS_MAX_BYTES"))
          c.max_bytes = val
        end

        if (val = Env.int("MUDIS_BUCKETS"))
          c.buckets = val
        end

        if (val = Env.int("MUDIS_MAX_TTL"))
          c.max_ttl = val
        end

        if (val = Env.int("MUDIS_DEFAULT_TTL"))
          c.default_ttl = val
        end

        c.persistence_enabled = Env.bool("MUDIS_PERSISTENCE_ENABLED", default: c.persistence_enabled)
        c.persistence_path = ENV["MUDIS_PERSISTENCE_PATH"] if ENV["MUDIS_PERSISTENCE_PATH"]
        c.persistence_format = Env.persistence_format if ENV["MUDIS_PERSISTENCE_FORMAT"]
        c.persistence_safe_write = Env.bool("MUDIS_PERSISTENCE_SAFE_WRITE", default: c.persistence_safe_write)
      end
    end

    def start_ipc_server!
      configure_mudis!
      Mudis.start_expiry_thread(interval: Env.expiry_interval)
      MudisWebCache::IPCExtensions.install!
      MudisServer.start!
      at_exit { Mudis.stop_expiry_thread }
    end

    def start_ipc_client!
      $mudis = MudisClient.new
      MudisWebCache::IPCExtensions.install!
      require "mudis_proxy"
    end
  end
end
