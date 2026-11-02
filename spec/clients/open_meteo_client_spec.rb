require "rails_helper"

RSpec.describe OpenMeteoClient do
  let(:raw) { JSON.parse(file_fixture("open_meteo/forecast.json").read) }
  let(:forecast_request) do
    stub_request(:get, OpenMeteoClient::ENDPOINT)
      .with(query: {
        "latitude" => "40.7478", "longitude" => "-73.9851",
        "current" => "temperature_2m,weather_code",
        "daily" => "temperature_2m_max,temperature_2m_min,weather_code",
        "temperature_unit" => "fahrenheit", "timezone" => "auto", "forecast_days" => "6"
      })
  end

  def forecast = OpenMeteoClient.new.forecast(latitude: 40.7478, longitude: -73.9851)

  it "parses current conditions and six days" do
    forecast_request.to_return(body: file_fixture("open_meteo/forecast.json").read)

    result = forecast

    expect(result.current_temperature).to eq(raw.dig("current", "temperature_2m"))
    expect(result.current_condition).to eq(WeatherCondition.describe(raw.dig("current", "weather_code")))
    expect(result.days.size).to eq(6)
    expect(result.today.date).to eq(Date.parse(raw.dig("daily", "time", 0)))
    expect(result.today.high).to eq(raw.dig("daily", "temperature_2m_max", 0))
    expect(result.today.low).to eq(raw.dig("daily", "temperature_2m_min", 0))
    expect(result.upcoming.size).to eq(5)
  end

  it "raises ServiceUnavailable when the API returns an error" do
    forecast_request.to_return(status: 400, body: '{"error":true,"reason":"Latitude must be in range of -90 to 90°."}')

    expect { forecast }.to raise_error(ServiceUnavailable)
  end

  it "raises ServiceUnavailable on an unexpected response shape" do
    forecast_request.to_return(body: "{}")

    expect { forecast }.to raise_error(ServiceUnavailable)
  end

  it "raises ServiceUnavailable on a null body or malformed sections" do
    bodies = [ "null", "[]", '{"current":[],"daily":{}}', raw.merge("daily" => raw["daily"].merge("time" => [ "nope" ] * 6)),
               raw.merge("daily" => raw["daily"].merge("temperature_2m_min" => [ 1 ])),
               raw.merge("current" => { "temperature_2m" => nil }) ]

    bodies.each do |body|
      stub_request(:get, OpenMeteoClient::ENDPOINT).with(query: hash_including("timezone" => "auto"))
        .to_return(body: body.is_a?(String) ? body : body.to_json)

      expect { forecast }.to raise_error(ServiceUnavailable)
    end
  end
end
