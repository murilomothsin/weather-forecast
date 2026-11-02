require "rails_helper"

RSpec.describe ForecastsHelper, type: :helper do
  def result(cached:, fetched_at: Time.current) = ForecastResult.new(location: nil, forecast: nil, cached: cached, fetched_at: fetched_at)

  it "labels a live result" do
    expect(helper.cache_status(result(cached: false))).to eq("Live data · fetched just now")
  end

  it "labels a cached result with how long ago it was fetched" do
    freeze_time do
      expect(helper.cache_status(result(cached: true, fetched_at: 12.minutes.ago))).to eq("Served from cache · fetched 12 minutes ago")
    end
  end
end
