# frozen_string_literal: true

require_relative "../config/boot"

RSpec.describe MudisWebCache::Boot do
  before do
    allow(Mudis).to receive(:load_snapshot!)
    allow(Mudis).to receive(:start_expiry_thread)
    allow(Mudis).to receive(:stop_expiry_thread)
    allow(MudisWebCache::IPCExtensions).to receive(:install!)
    allow(MudisServer).to receive(:start!)
  end

  it "loads snapshot when persistence is enabled" do
    ENV["MUDIS_PERSISTENCE_ENABLED"] = "true"

    described_class.start_ipc_server!

    expect(Mudis).to have_received(:load_snapshot!)
  end

  it "does not load snapshot when persistence is disabled" do
    ENV["MUDIS_PERSISTENCE_ENABLED"] = "false"

    described_class.start_ipc_server!

    expect(Mudis).not_to have_received(:load_snapshot!)
  end
end
