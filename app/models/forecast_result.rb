ForecastResult = Data.define(:location, :forecast, :cached, :fetched_at) do
  def cached? = cached
end
