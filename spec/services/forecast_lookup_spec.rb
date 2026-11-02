require "rails_helper"

RSpec.describe ForecastLookup do
  let(:census) { instance_double(CensusGeocoder) }
  let(:zip_geocoder) { instance_double(ZipGeocoder) }
  let(:weather) { instance_double(OpenMeteoClient) }
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  subject(:lookup) { described_class.new(census:, zip_geocoder:, weather:, cache:) }

  let(:street) { Location.new(matched_address: "350 5TH AVE, NEW YORK, NY, 10118", zip: "10118", latitude: 40.7478, longitude: -73.9851, approximate: false) }
  let(:zip_loc) { Location.new(matched_address: "New York, New York", zip: "10118", latitude: 40.714, longitude: -74.006, approximate: true) }
  let(:forecast) do
    Forecast.new(current_temperature: 54.0, current_condition: "Partly cloudy",
                 days: [ DailyForecast.new(date: Date.new(2026, 11, 2), high: 61.0, low: 47.0, condition: "Partly cloudy") ])
  end
  let(:address) { "350 5th Ave, New York, NY" }

  before do
    allow(census).to receive(:locate).and_return(street)
    allow(zip_geocoder).to receive(:locate).and_return(zip_loc)
    allow(weather).to receive(:forecast).and_return(forecast)
  end

  it "geocodes a street address with the Census and returns a live result" do
    freeze_time

    result = lookup.call(address)

    expect(census).to have_received(:locate).with(address)
    expect(weather).to have_received(:forecast).with(latitude: 40.7478, longitude: -73.9851)
    expect(result.location).to eq(street)
    expect(result.forecast).to eq(forecast)
    expect(result.cached?).to be(false)
    expect(result.fetched_at).to eq(Time.current)
  end

  it "serves the second lookup from cache with the original fetch time" do
    first = lookup.call(address)
    travel 10.minutes
    second = lookup.call(address)

    expect(second.cached?).to be(true)
    expect(second.fetched_at).to eq(first.fetched_at)
    expect(weather).to have_received(:forecast).once
  end

  it "shares the forecast between addresses in the same ZIP" do
    lookup.call(address)
    second = lookup.call("20 W 34th St, New York, NY")

    expect(second.cached?).to be(true)
  end

  it "shares the forecast between a ZIP search and a street address in that ZIP" do
    lookup.call("10118")
    second = lookup.call(address)

    expect(second.cached?).to be(true)
    expect(weather).to have_received(:forecast).once
  end

  it "is still cached after 29 minutes" do
    lookup.call(address)
    travel 29.minutes

    expect(lookup.call(address).cached?).to be(true)
  end

  it "fetches live again after 31 minutes" do
    lookup.call(address)
    travel 31.minutes

    expect(lookup.call(address).cached?).to be(false)
    expect(weather).to have_received(:forecast).twice
  end

  it "sends a 5-digit ZIP to the ZIP geocoder" do
    lookup.call("10118")

    expect(zip_geocoder).to have_received(:locate).with("10118")
    expect(census).not_to have_received(:locate)
  end

  it "sends a ZIP+4 as 5 digits" do
    lookup.call("10118-0110")

    expect(zip_geocoder).to have_received(:locate).with("10118")
  end

  it "accepts a ZIP surrounded by spaces" do
    lookup.call("  10118 ")

    expect(zip_geocoder).to have_received(:locate).with("10118")
  end

  it "sends anything that is not a ZIP to the Census" do
    allow(census).to receive(:locate).and_raise(AddressNotFound)

    [ "New York, NY", "1234", "123456" ].each do |input|
      expect { lookup.call(input) }.to raise_error(AddressNotFound)
      expect(census).to have_received(:locate).with(input)
    end
    expect(zip_geocoder).not_to have_received(:locate)
  end

  it "reuses the geocode cache for the same address typed differently" do
    lookup.call(address)
    lookup.call("  350  5TH AVE, new york, ny ")

    expect(census).to have_received(:locate).once
  end

  it "does not cache geocoding failures" do
    calls = [ -> { raise AddressNotFound }, -> { street } ]
    allow(census).to receive(:locate) { calls.shift.call }

    expect { lookup.call(address) }.to raise_error(AddressNotFound)
    expect(lookup.call(address).location).to eq(street)
    expect(census).to have_received(:locate).twice
  end

  it "does not cache weather failures" do
    calls = [ -> { raise ServiceUnavailable }, -> { forecast } ]
    allow(weather).to receive(:forecast) { calls.shift.call }

    expect { lookup.call(address) }.to raise_error(ServiceUnavailable)
    expect(lookup.call(address).cached?).to be(false)
  end

  it "rejects blank, oversized and non-string input before calling any API" do
    blank = "Please enter a US street address or a 5-digit ZIP code."
    too_long = "That address is too long. Please use at most 200 characters."

    expect { lookup.call("   ") }.to raise_error(InvalidAddress, blank)
    expect { lookup.call("a" * 201) }.to raise_error(InvalidAddress, too_long)
    expect { lookup.call([ "x" ]) }.to raise_error(InvalidAddress, blank)
    expect { lookup.call(nil) }.to raise_error(InvalidAddress, blank)
    expect(census).not_to have_received(:locate)
    expect(zip_geocoder).not_to have_received(:locate)
    expect(weather).not_to have_received(:forecast)
  end
end
