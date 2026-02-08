# frozen_string_literal: true

require "open3"
require "rbconfig"

RSpec.describe "CLI bootstrap" do
  it "errors when IPC mode is disabled" do
    cli_path = File.expand_path("../config/cli.rb", __dir__)
    env = { "MUDIS_IPC_MODE" => "false" }

    stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, cli_path)

    expect(status.exitstatus).to eq(1)
    expect(stdout).to eq("")
    expect(stderr).to include("Mudis CLI requires IPC mode to connect to the running cache.")
  end
end
