class CensusGeocoder
  ENDPOINT = "https://geocoding.geo.census.gov/geocoder/locations/onelineaddress"

  def locate(address)
    body = JsonHttp.get(ENDPOINT, address: address, benchmark: "Public_AR_Current", format: "json")
    Response.new(body).to_location
  end
end
