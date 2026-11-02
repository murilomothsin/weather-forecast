class ServiceUnavailable < StandardError
  def initialize(msg = "The weather service is temporarily unavailable. Please try again in a moment.") = super
end
