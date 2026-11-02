Location = Data.define(:matched_address, :zip, :latitude, :longitude, :approximate) do
  def approximate? = approximate
end
