class ZipGeocoder::Response
  def initialize(body, zip)
    @body = body
    @zip = zip
  end

  def to_location
    match = results.find { |result| result.is_a?(Hash) && Array(result["postcodes"]).include?(@zip) } or raise AddressNotFound

    latitude, longitude = match["latitude"], match["longitude"]
    unexpected_shape! unless latitude.is_a?(Numeric) && longitude.is_a?(Numeric)

    Location.new(matched_address: "#{match["name"]}, #{match["admin1"]}", zip: @zip, latitude: latitude, longitude: longitude, approximate: true)
  end

  private

  def results
    unexpected_shape! unless @body.is_a?(Hash)
    list = @body.fetch("results", [])
    list.is_a?(Array) ? list : unexpected_shape!
  end

  def unexpected_shape!
    Rails.logger.warn("ZipGeocoder unexpected response shape")
    raise ServiceUnavailable
  end
end
