require "rails_helper"

RSpec.describe "Test environment" do
  it "blocks real HTTP requests" do
    expect { Net::HTTP.get(URI("https://example.com")) }
      .to raise_error(WebMock::NetConnectNotAllowedError)
  end

  it "uses a real in-memory cache" do
    expect(Rails.cache).to be_a(ActiveSupport::Cache::MemoryStore)
  end
end
