require "rails_helper"

RSpec.describe ZipGeocoder do
  let(:zip) { "10118" }
  let(:geocoding_request) do
    stub_request(:get, ZipGeocoder::ENDPOINT)
      .with(query: { "name" => zip, "countryCode" => "US", "count" => "5" })
  end

  it "returns an approximate location for the ZIP" do
    geocoding_request.to_return(body: file_fixture("open_meteo/geocoding_10118.json").read)

    location = ZipGeocoder.new.locate(zip)

    expect(location.matched_address).to eq("New York, New York")
    expect(location.zip).to eq("10118")
    expect(location.latitude).to be_within(0.01).of(40.714)
    expect(location.longitude).to be_within(0.01).of(-74.006)
    expect(location.approximate?).to be(true)
  end

  it "raises AddressNotFound when there are no results" do
    geocoding_request.to_return(body: file_fixture("open_meteo/geocoding_not_found.json").read)

    expect { ZipGeocoder.new.locate(zip) }.to raise_error(AddressNotFound)
  end

  it "raises AddressNotFound when no result lists the ZIP" do
    body = JSON.parse(file_fixture("open_meteo/geocoding_10118.json").read)
    body["results"].each { |result| result["postcodes"] = [ "10001" ] }
    geocoding_request.to_return(body: body.to_json)

    expect { ZipGeocoder.new.locate(zip) }.to raise_error(AddressNotFound)
  end

  it "raises ServiceUnavailable when the body is not a JSON object" do
    geocoding_request.to_return(body: "null")

    expect { ZipGeocoder.new.locate(zip) }.to raise_error(ServiceUnavailable)
  end

  it "raises ServiceUnavailable when the API fails" do
    geocoding_request.to_return(status: 400, body: '{"error":true,"reason":"x"}')

    expect { ZipGeocoder.new.locate(zip) }.to raise_error(ServiceUnavailable)
  end
end
