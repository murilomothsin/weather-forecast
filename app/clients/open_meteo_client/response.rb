class OpenMeteoClient::Response
  DAILY_KEYS = %w[time temperature_2m_max temperature_2m_min weather_code].freeze

  def initialize(body)
    @body = body
  end

  def to_forecast
    temperature = current["temperature_2m"]
    unexpected_shape! unless temperature.is_a?(Numeric)

    Forecast.new(current_temperature: temperature.to_f, current_condition: WeatherCondition.describe(current["weather_code"]), days: days)
  end

  private

  def current = section("current")

  def days
    columns = DAILY_KEYS.map { |key| section("daily")[key] }
    unexpected_shape! unless columns.all?(Array) && columns.map(&:size).uniq.one? && columns.first.any?

    columns.transpose.map do |date, high, low, code|
      unexpected_shape! unless high.is_a?(Numeric) && low.is_a?(Numeric)
      DailyForecast.new(date: Date.parse(date), high: high.to_f, low: low.to_f, condition: WeatherCondition.describe(code))
    end
  rescue Date::Error, TypeError
    unexpected_shape!
  end

  def section(name)
    value = @body[name] if @body.is_a?(Hash)
    value.is_a?(Hash) ? value : unexpected_shape!
  end

  def unexpected_shape!
    Rails.logger.warn("OpenMeteoClient unexpected response shape")
    raise ServiceUnavailable
  end
end
