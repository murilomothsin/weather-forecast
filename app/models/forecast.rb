Forecast = Data.define(:current_temperature, :current_condition, :days) do
  def today = days.first
  def upcoming = days.drop(1)
end
