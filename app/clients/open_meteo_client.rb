class OpenMeteoClient
  ENDPOINT = "https://api.open-meteo.com/v1/forecast"

  def forecast(latitude:, longitude:)
    body = JsonHttp.get(ENDPOINT, latitude: latitude, longitude: longitude,
                                  current: "temperature_2m,weather_code",
                                  daily: "temperature_2m_max,temperature_2m_min,weather_code",
                                  temperature_unit: "fahrenheit", timezone: "auto", forecast_days: 6)
    Response.new(body).to_forecast
  end
end
