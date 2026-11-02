require "rails_helper"

RSpec.describe CensusGeocoder do
  let(:address) { "350 5th Ave, New York, NY" }
  let(:census_request) do
    stub_request(:get, CensusGeocoder::ENDPOINT)
      .with(query: { "address" => address, "benchmark" => "Public_AR_Current", "format" => "json" })
  end

  it "returns the matched location" do
    census_request.to_return(body: file_fixture("census/match.json").read)

    location = CensusGeocoder.new.locate(address)

    expect(location.matched_address).to eq("350 5TH AVE, NEW YORK, NY, 10118")
    expect(location.zip).to eq("10118")
    expect(location.latitude).to be_within(0.001).of(40.7478)
    expect(location.longitude).to be_within(0.001).of(-73.9851)
    expect(location.approximate?).to be(false)
  end

  it "raises AddressNotFound when there are no matches" do
    census_request.to_return(body: file_fixture("census/no_match.json").read)

    expect { CensusGeocoder.new.locate(address) }.to raise_error(AddressNotFound)
  end

  it "raises AddressNotFound when the match has no ZIP" do
    body = JSON.parse(file_fixture("census/match.json").read)
    body["result"]["addressMatches"][0]["addressComponents"]["zip"] = ""
    census_request.to_return(body: body.to_json)

    expect { CensusGeocoder.new.locate(address) }.to raise_error(AddressNotFound)
  end

  it "raises ServiceUnavailable on an unexpected response shape" do
    census_request.to_return(body: "{}")

    expect { CensusGeocoder.new.locate(address) }.to raise_error(ServiceUnavailable)
  end

  it "raises ServiceUnavailable when the body is not a JSON object" do
    census_request.to_return(body: "null")

    expect { CensusGeocoder.new.locate(address) }.to raise_error(ServiceUnavailable)
  end

  it "raises ServiceUnavailable when the API fails" do
    census_request.to_return(status: 500)

    expect { CensusGeocoder.new.locate(address) }.to raise_error(ServiceUnavailable)
  end
end
