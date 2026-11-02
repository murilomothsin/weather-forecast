require "net/http"

module JsonHttp
  NETWORK_ERRORS = [
    Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, IOError,
    Net::ProtocolError, Net::HTTPBadResponse
  ].freeze

  def self.get(url, params)
    uri = URI(url)
    uri.query = URI.encode_www_form(params)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
      http.get(uri.request_uri)
    end
    body = response.body.to_s
    unavailable!(uri, "status=#{response.code} body=#{body[0, 200]}") unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(body)
  rescue JSON::ParserError
    unavailable!(uri, "status=#{response.code} body=#{body[0, 200]}")
  rescue *NETWORK_ERRORS => e
    unavailable!(uri, "#{e.class}: #{e.message}")
  end

  def self.unavailable!(uri, detail)
    Rails.logger.warn("JsonHttp #{uri.host}#{uri.path} #{detail}")
    raise ServiceUnavailable
  end
  private_class_method :unavailable!
end
