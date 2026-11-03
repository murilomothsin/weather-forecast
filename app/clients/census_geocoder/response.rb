class CensusGeocoder::Response
  def initialize(body)
    @body = body
  end

  def to_location
    match = matches.first or raise AddressNotFound
    zip = match.dig("addressComponents", "zip")
    raise AddressNotFound if zip.blank?

    latitude, longitude = match.dig("coordinates", "y"), match.dig("coordinates", "x")
    unexpected_shape! unless latitude.is_a?(Numeric) && longitude.is_a?(Numeric)

    Location.new(matched_address: match["matchedAddress"], zip: zip, latitude: latitude, longitude: longitude, approximate: false)
  end

  private

  def matches
    result = @body["result"] if @body.is_a?(Hash)
    list = result["addressMatches"] if result.is_a?(Hash)
    list.is_a?(Array) ? list : unexpected_shape!
  end

  def unexpected_shape!
    Rails.logger.warn("CensusGeocoder unexpected response shape")
    raise ServiceUnavailable
  end
end
