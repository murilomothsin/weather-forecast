# Weather Forecast

A small Rails app that takes a US address (or just a ZIP code) and shows the weather for it: the current temperature and conditions, today's high and low, and the next five days. Forecasts are cached for 30 minutes per ZIP code, and the page says whether what you are looking at was fetched live or served from the cache.

No API keys or accounts are needed.

## Requirements

- Ruby 3.4.4 (see `.ruby-version`) and Bundler.
- Outbound HTTPS access, since the app calls three public APIs (see "APIs used").
- Everything else (gems, the SQLite database, foreman for `bin/dev`) is installed or created by `bin/setup` and `bin/dev`.

## Run it

```sh
git clone https://github.com/murilomothsin/weather-forecast.git
cd weather-forecast
bin/setup
```

`bin/setup` installs the gems, prepares the SQLite database (including the cache table) and then starts the development server through `bin/dev` (the Rails server plus the Tailwind CSS watcher, managed by foreman, which `bin/dev` installs with `gem install foreman` if it is missing). When it is up, open <http://localhost:3000>.

Useful variations:

- `bin/setup --skip-server` does the setup only. Start the server later with `bin/dev`.
- Port 3000 taken? `PORT=3001 bin/dev` (and open `http://localhost:3001`).


## Run the tests

```sh
bundle exec rspec
```

`bin/ci` runs the full local pipeline: setup, RuboCop, bundler-audit, Brakeman and the RSpec suite (see `config/ci.rb`).

The suite never touches the network: WebMock blocks real HTTP and the specs use responses recorded from the real APIs (`spec/fixtures/files/`).

## How it works

```
GET /?address=...
  -> ForecastsController#show
       -> ForecastLookup#call(address)
            1. validate (blank or > 200 chars -> InvalidAddress) and squish whitespace
            2. classify the input: 5-digit ZIP (ZIP+4 allowed), or street address
            3. geocode, cached 30 days under "geocode/v1/<zip or lowercased address>"
                 ZIP             -> ZipGeocoder    (Open-Meteo Geocoding) -> Location, approximate
                 street address  -> CensusGeocoder (US Census Geocoder)   -> Location, street-level
            4. forecast, cached 30 minutes under "forecast/v1/<zip>"
                 miss            -> OpenMeteoClient (Open-Meteo Forecast) -> Forecast
            5. return ForecastResult(location, forecast, cached?, fetched_at)
       -> view: "Address found" box, "Weather" box,
                "Live data" or "Served from cache" line
```

The street address is sent to the Census as typed (only whitespace is squished); lowercasing is only used to build the cache key.

Errors are domain errors raised anywhere in that chain and rescued in the controller:

| Error | When | HTTP status |
| --- | --- | --- |
| `InvalidAddress` | blank input, more than 200 characters, or a non-string parameter | 422 |
| `AddressNotFound` | the geocoder has no match (or the match has no ZIP) | 422 |
| `ServiceUnavailable` | timeout, network error, non-2xx response, invalid JSON, or an unexpected payload shape from any of the three APIs | 503 |
| Rate limit | more than 10 searches in a minute from the same IP | 429 |

The user sees a fixed, readable message for each; the upstream's own error text is never shown.

### APIs used

All three are public and keyless.

| API | Used for |
| --- | --- |
| [US Census Geocoder](https://geocoding.geo.census.gov/geocoder/Geocoding_Services_API.html) (`locations/onelineaddress`) | Street address to normalized address, ZIP and coordinates. A public US government service covering the US, Puerto Rico and the US Island Areas. |
| [Open-Meteo Geocoding](https://open-meteo.com/en/docs/geocoding-api) (`/v1/search`) | ZIP-only input to city-center coordinates, marked approximate. |
| [Open-Meteo Forecast](https://open-meteo.com/en/docs) (`/v1/forecast`) | Current temperature and condition, plus daily high/low and condition for today and the next 5 days. Requested with `temperature_unit=fahrenheit` and `timezone=auto`, so dates are already in the location's own time zone. |

Open-Meteo's free API is offered for non-commercial use (a subscription and an API key are for commercial use), which fits an exercise like this one. Usage limits apply to the free tier.

### Where to look

- `app/controllers/forecasts_controller.rb`: the single action, error-to-status mapping.
- `app/services/forecast_lookup.rb`: validation, classification, both caches, hit detection.
- `app/clients/`: `CensusGeocoder`, `ZipGeocoder`, `OpenMeteoClient`, each with a `Response` class that turns vendor JSON into domain objects, and `JsonHttp`, the shared `Net::HTTP` helper.
- `app/models/`: `Location`, `Forecast`, `DailyForecast`, `ForecastResult` (immutable `Data` objects) and `WeatherCondition` (WMO weather code to English text).
- `app/errors/`: the three domain errors. `AddressNotFound` and `ServiceUnavailable` carry their user-facing messages; the two `InvalidAddress` messages are raised in `ForecastLookup`.
- `app/views/forecasts/show.html.erb` and `app/helpers/forecasts_helper.rb`: the page and the cache line.
- `spec/`: clients, service, helper, model and request specs.

## Assumptions and interpretations

- **Input is a street address or a 5-digit ZIP.** For a street address the ZIP is optional: the Census geocoder finds it. A ZIP+4 is accepted and cut to its first 5 digits.
- **A city on its own is not accepted.** A city has many ZIP codes, so there would be no single ZIP to key the cache on. It ends in the "We couldn't find that location" message.
- **ZIP-only searches use approximate coordinates.** The ZIP geocoder returns the center of the matching city, not of the ZIP, and the page says "approximate location (city center)".
- **"Same ZIP" is the cache boundary.** The forecast cache is keyed by ZIP, as the requirement is worded, so a ZIP search and a street-address search in the same ZIP share one entry for 30 minutes, and whichever came first decided the coordinates (exact point or city center). The "Address found" box always shows the location of the current search, while the forecast under it may have been fetched for the other point. For a weather forecast the difference is small, and I accepted it rather than keying on coordinates, which would make two addresses in the same ZIP miss each other's cache.
- **Fahrenheit and English only**, with no unit toggle.

## Design decisions and trade-offs

**Keyless providers.** The Census geocoder and Open-Meteo need no keys, so `bin/setup` gives a working app with no secrets to hand over.

**Two geocoders.** The Census geocoder resolves street addresses only: a bare ZIP or a bare city returns no match (its documentation says a structure number and street name are required, and both a bare ZIP and a bare city came back empty when I tried them against the live API). To support ZIP-only input, that case goes to the Open-Meteo geocoder instead. The price is that a ZIP search is approximate, which the page states.

**Thin clients on `Net::HTTP`, no HTTP gem.** Three GET requests did not justify a dependency. `JsonHttp` is the single place that performs requests (5 second open and read timeouts), turns network errors, non-2xx responses and invalid JSON into `ServiceUnavailable`, and logs the technical detail (host, path, status, start of the body) while the user sees only the fixed message. Each client has a `Response` class that translates the vendor JSON into `Location`, `Forecast` and `DailyForecast`, so nothing past the clients knows a vendor format.

**Domain errors, no blanket rescue.** The controller rescues only `InvalidAddress`, `AddressNotFound` and `ServiceUnavailable`. There is no `rescue StandardError`: a genuine bug surfaces as a 500 instead of being disguised as "service unavailable".

**Cache.**

- Solid Cache, stored in the primary SQLite database. The cache table is the only table in the app, so a separate cache database would be extra configuration for nothing. The cache survives restarts and is shared between processes.
- Geocoding is cached for 30 days: an address rarely changes ZIP, and it saves a call on repeat searches. The forecast is cached for 30 minutes, as required. Keys are `geocode/v1/<ZIP or lowercased address>` and `forecast/v1/<ZIP>`; the `v1` lets the cache be invalidated by bumping it if the stored format changes.
- Failures are never cached: the error is raised inside the `Rails.cache.fetch` block, so nothing is written.
- A cache hit is "the `fetch` block did not run". There is no `exist?` check before `fetch`, which would be a race and an extra round trip. The entry stores the forecast together with its `fetched_at`, which is what the "Served from cache · fetched N minutes ago" line shows, so the indicator reflects what was actually served. It describes the forecast cache only: a search can reuse a cached geocode and still say "Live data".

**Rate limit.** Rails' built-in `rate_limit` allows 10 searches per minute per IP. Only requests with an address count, so opening the empty form is never limited. The counter lives in the same cache, and the search over the limit gets an HTTP 429 with a message.

## Challenges

- **Solid Cache needs Active Job.** The app was generated without Active Job, but Solid Cache depends on it, and the app failed to boot with eager loading until `active_job/railtie` was enabled in `config/application.rb`.
- **The Census geocoder does not take a bare ZIP or city.** It returns no match without a street address, which is why the second geocoder exists.
- **Open-Meteo returns daily data as parallel arrays** (dates, highs, lows, codes). `OpenMeteoClient::Response` validates them strictly (all arrays present and of equal length, numeric temperatures, parseable dates) before building the days, so a malformed payload becomes a 503 instead of an unhandled 500.

## Next steps

- Retries with backoff for transient upstream failures such as connect timeout.
- Serve stale data when an upstream is down, instead of an error, up to a reasonable age limit.
- `race_condition_ttl` on the forecast cache, to avoid a stampede when a popular ZIP expires.
- Search by city (needs a policy for which ZIP, or a different cache key).
- Other countries (needs a different geocoder than the Census one).
