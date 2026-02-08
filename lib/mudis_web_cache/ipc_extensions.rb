# frozen_string_literal: true

module MudisWebCache
  module IPCExtensions
    module_function

    EXTRA_COMMANDS = {
      "keys" => lambda do |r|
        Mudis.keys(namespace: r[:namespace])
      end,
      "clear_namespace" => lambda do |r|
        Mudis.clear_namespace(namespace: r[:namespace])
        true
      end,
      "inspect" => lambda do |r|
        Mudis.inspect(r[:key], namespace: r[:namespace])
      end,
      "least_touched" => lambda do |r|
        Mudis.least_touched((r[:count] || 10).to_i)
      end,
      "all_keys" => lambda do |_r|
        Mudis.all_keys
      end
    }.freeze

    def install!
      extend_server!
      extend_client!
      extend_proxy!
    end

    def extend_server!
      MudisServer.singleton_class.class_eval do
        define_method(:command_handlers) do
          @command_handlers ||= MudisServer::COMMANDS.merge(MudisWebCache::IPCExtensions::EXTRA_COMMANDS)
        end

        define_method(:process_request) do |req|
          handler = command_handlers[req[:cmd]]
          raise "Unknown command: #{req[:cmd]}" unless handler

          handler.call(req)
        end
      end
    end

    def extend_client!
      MudisClient.class_eval do
        def keys(namespace:)
          command("keys", namespace: namespace)
        end

        def clear_namespace(namespace:)
          command("clear_namespace", namespace: namespace)
        end

        def inspect(key, namespace: nil)
          command("inspect", key: key, namespace: namespace)
        end

        def least_touched(count = 10)
          command("least_touched", count: count)
        end

        def all_keys
          command("all_keys")
        end
      end
    end

    def extend_proxy!
      return unless defined?($mudis) && $mudis

      class << Mudis
        def keys(namespace:)
          $mudis.keys(namespace: namespace)
        end

        def clear_namespace(namespace:)
          $mudis.clear_namespace(namespace: namespace)
        end

        def inspect(*a, **k)
          $mudis.inspect(*a, **k)
        end

        def least_touched(n = 10)
          $mudis.least_touched(n)
        end

        def all_keys
          $mudis.all_keys
        end
      end
    end
  end
end
