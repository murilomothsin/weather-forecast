class ZipGeocoder
  ENDPOINT = "https://geocoding-api.open-meteo.com/v1/search"

  def locate(zip)
    body = JsonHttp.get(ENDPOINT, name: zip, countryCode: "US", count: 5)
    Response.new(body, zip).to_location
  end
end
