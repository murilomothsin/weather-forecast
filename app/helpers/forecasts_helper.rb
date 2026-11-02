module ForecastsHelper
  def cache_status(result)
    return "Live data · fetched just now" unless result.cached?

    "Served from cache · fetched #{time_ago_in_words(result.fetched_at)} ago"
  end
end
