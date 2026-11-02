class CensusGeocoder::Response
  def initialize(body)
    @body = body
  end

  def to_location
    match = matches.first or raise AddressNotFound
    zip = match.dig("addressComponents", "zip")
    raise AddressNotFound if zip.blank?

    Location.new(matched_address: match["matchedAddress"], zip: zip,
                 latitude: match.dig("coordinates", "y"), longitude: match.dig("coordinates", "x"), approximate: false)
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
