require "rails_helper"

RSpec.describe WeatherCondition do
  it { expect(WeatherCondition.describe(0)).to eq("Clear sky") }
  it { expect(WeatherCondition.describe(2)).to eq("Partly cloudy") }
  it { expect(WeatherCondition.describe(95)).to eq("Thunderstorm") }
  it { expect(WeatherCondition.describe(999)).to eq("Unknown") }
  it { expect(WeatherCondition.describe(nil)).to eq("Unknown") }
end
