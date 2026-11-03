require "rails_helper"

RSpec.describe "Forecasts", type: :request do
  let(:street) { "350 5th Ave, New York, NY" }
  let(:placeholder) { "e.g. 350 5th Ave, New York, NY 10118 or 10118" }

  def stub_census(fixture)
    stub_request(:get, CensusGeocoder::ENDPOINT)
      .with(query: { "address" => street, "benchmark" => "Public_AR_Current", "format" => "json" })
      .to_return(body: file_fixture("census/#{fixture}.json").read)
  end

  def stub_weather(**response)
    response = { body: file_fixture("open_meteo/forecast.json").read } if response.empty?
    stub_request(:get, %r{api\.open-meteo\.com/v1/forecast}).to_return(**response)
  end

  it "renders the search form" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('name="address"', CGI.escapeHTML(placeholder))
    expect(response.body).not_to include("Address found")
  end

  it "shows the location and live weather for a street address" do
    stub_census("match")
    stub_weather

    get root_path, params: { address: street }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("350 5TH AVE, NEW YORK, NY, 10118", "Live data · fetched just now", %(value="#{street}"))
  end

  it "shows the current conditions, today's range and the five upcoming days" do
    stub_census("match")
    stub_weather
    raw = JSON.parse(file_fixture("open_meteo/forecast.json").read)
    daily = raw["daily"]
    (_, today_high, today_low), *upcoming = daily["time"].zip(daily["temperature_2m_max"], daily["temperature_2m_min"])

    get root_path, params: { address: street }

    expect(response.body).to include("#{raw.dig("current", "temperature_2m").round}°F", WeatherCondition.describe(raw.dig("current", "weather_code")))
    expect(response.body).to include("H #{today_high.round}°", "L #{today_low.round}°")
    expect(response.body.scan("H #{today_high.round}°").size).to eq(1)
    expect(upcoming.size).to eq(5)
    upcoming.each do |date, high, low|
      expect(response.body).to match(/#{Date.parse(date).strftime("%a")}\b.*?H #{high.round}°.*?L #{low.round}°/m)
    end
  end

  it "shows the cache indicator on the second search" do
    stub_census("match")
    stub_weather

    2.times { get root_path, params: { address: street } }

    expect(response.body).to include("Served from cache")
  end

  it "marks a ZIP search as an approximate location" do
    stub_request(:get, ZipGeocoder::ENDPOINT)
      .with(query: { "name" => "10118", "countryCode" => "US", "count" => "5" })
      .to_return(body: file_fixture("open_meteo/geocoding_10118.json").read)
    stub_weather

    get root_path, params: { address: "10118" }

    expect(response.body).to include("New York, New York", "approximate location (city center)")
  end

  it "returns 422 when the address is not found" do
    stub_census("no_match")

    get root_path, params: { address: street }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(CGI.escapeHTML(AddressNotFound.new.message), 'role="alert"')
  end

  it "returns 422 for a blank address" do
    get root_path, params: { address: "" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Please enter a US street address or a 5-digit ZIP code.")
  end

  it "returns the HTML error page even when the client asks for JSON" do
    get root_path, params: { address: "" }, headers: { "Accept" => "application/json" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Please enter a US street address or a 5-digit ZIP code.")
  end

  it "returns 422 for a non-string address" do
    get root_path, params: { address: [ "x" ] }

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "returns 503 without leaking the upstream reason when the weather API fails" do
    stub_census("match")
    stub_weather(status: 400, body: '{"error":true,"reason":"secret detail"}')

    get root_path, params: { address: street }

    expect(response).to have_http_status(:service_unavailable)
    expect(response.body).to include(ServiceUnavailable.new.message)
    expect(response.body).not_to include("secret detail")
  end

  it "filters the typed address from the logs" do
    filtered = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter("address" => street)

    expect(filtered).to eq("address" => "[FILTERED]")
  end

  describe "rate limit" do
    it "returns 429 with a message after 10 searches in a minute" do
      10.times do
        get root_path, params: { address: "" }
        expect(response).to have_http_status(:unprocessable_content)
      end

      get root_path, params: { address: "" }

      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("Too many searches. Please wait a minute and try again.", 'role="alert"')
    end

    it "does not count visits without an address" do
      11.times { get root_path }

      expect(response).to have_http_status(:ok)
    end
  end
end
