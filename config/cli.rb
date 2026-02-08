# frozen_string_literal: true

require_relative "boot"

ipc_enabled = ENV.fetch("MUDIS_IPC_MODE", "true").to_s.downcase == "true"

unless ipc_enabled
  warn "Mudis CLI requires IPC mode to connect to the running cache."
  warn "Set MUDIS_IPC_MODE=true (and run the server with workers enabled) or use the HTTP API instead."
  exit 1
end

MudisWebCache::Boot.start_ipc_client!
