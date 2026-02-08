# frozen_string_literal: true

require_relative "config/boot"
require_relative "lib/mudis_web_cache"

run MudisWebCache::App.new
