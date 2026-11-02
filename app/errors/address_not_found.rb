class AddressNotFound < StandardError
  def initialize(msg = "We couldn't find that location. Please enter a valid US street address (e.g. 350 5th Ave, New York, NY 10118) or a 5-digit ZIP code.") = super
end
