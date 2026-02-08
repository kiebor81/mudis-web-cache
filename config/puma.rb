# frozen_string_literal: true

workers_env = ENV.fetch("WEB_CONCURRENCY", "2")
workers_count = Integer(workers_env) rescue 2
workers_count = 1 if workers_count < 1

threads_env = ENV.fetch("PUMA_THREADS", "5")
threads_count = Integer(threads_env) rescue 5
threads_count = 1 if threads_count < 1

if Gem.win_platform?
  workers_count = 0
end

workers workers_count
threads threads_count, threads_count
preload_app!

port ENV.fetch("PORT", 3000)

ssl_enabled = ENV["MUDIS_SSL_ENABLED"].to_s.downcase == "true"

if ssl_enabled
  ssl_port = Integer(ENV.fetch("MUDIS_SSL_PORT", ENV.fetch("PORT", 3000))) rescue 3000
  cert = ENV["MUDIS_SSL_CERT"]
  key = ENV["MUDIS_SSL_KEY"]

  if cert && key
    ssl_bind "0.0.0.0", ssl_port,
             cert: cert,
             key: key,
             verify_mode: ENV.fetch("MUDIS_SSL_VERIFY_MODE", "none"),
             ca: ENV["MUDIS_SSL_CA"],
             min_version: ENV["MUDIS_SSL_MIN_VERSION"],
             max_version: ENV["MUDIS_SSL_MAX_VERSION"]
  else
    warn "[puma] SSL enabled but MUDIS_SSL_CERT or MUDIS_SSL_KEY is missing; continuing without SSL."
  end
end

environment ENV.fetch("RACK_ENV", "production")

ipc_enabled = ENV.fetch("MUDIS_IPC_MODE", "true").to_s.downcase == "true"

if ipc_enabled && workers_count > 0
  before_fork do
    ENV["MUDIS_IPC_SERVER"] = "true"
    require_relative "boot"
    MudisWebCache::Boot.start_ipc_server!
  end

  on_worker_boot do
    ENV["MUDIS_IPC_CLIENT"] = "true"
    require_relative "boot"
    MudisWebCache::Boot.start_ipc_client!
  end

else
  require_relative "boot"
  MudisWebCache::Boot.configure_mudis!
  Mudis.start_expiry_thread(interval: MudisWebCache::Env.expiry_interval)
  at_exit { Mudis.stop_expiry_thread }
end
