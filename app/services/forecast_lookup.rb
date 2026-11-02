class ForecastLookup
  ZIP_PATTERN = /\A(\d{5})(-\d{4})?\z/
  MAX_LENGTH = 200
  GEOCODE_TTL = 30.days
  FORECAST_TTL = 30.minutes

  def initialize(census: CensusGeocoder.new, zip_geocoder: ZipGeocoder.new, weather: OpenMeteoClient.new, cache: Rails.cache)
    @census = census
    @zip_geocoder = zip_geocoder
    @weather = weather
    @cache = cache
  end

  def call(query)
    location = geocode(clean(query))
    entry, cached = fetch_forecast(location)
    ForecastResult.new(location: location, forecast: entry[:forecast], cached: cached, fetched_at: entry[:fetched_at])
  end

  private

  attr_reader :census, :zip_geocoder, :weather, :cache

  def clean(query)
    raise InvalidAddress, "Please enter a US street address or a 5-digit ZIP code." unless query.is_a?(String) && query.present?
    raise InvalidAddress, "That address is too long. Please use at most #{MAX_LENGTH} characters." if query.length > MAX_LENGTH

    query.squish
  end

  def geocode(cleaned)
    zip = cleaned[ZIP_PATTERN, 1]
    cache.fetch("geocode/v1/#{zip || cleaned.downcase}", expires_in: GEOCODE_TTL) do
      zip ? zip_geocoder.locate(zip) : census.locate(cleaned)
    end
  end

  def fetch_forecast(location)
    cached = true
    entry = cache.fetch("forecast/v1/#{location.zip}", expires_in: FORECAST_TTL) do
      cached = false
      { forecast: weather.forecast(latitude: location.latitude, longitude: location.longitude), fetched_at: Time.current }
    end
    [ entry, cached ]
  end
end
