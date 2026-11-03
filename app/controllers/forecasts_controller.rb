class ForecastsController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: :show, if: -> { params.key?(:address) },
             with: -> { render_error("Too many searches. Please wait a minute and try again.", :too_many_requests) }

  rescue_from(InvalidAddress, AddressNotFound) { |e| render_error(e.message, :unprocessable_content) }
  rescue_from(ServiceUnavailable) { |e| render_error(e.message, :service_unavailable) }

  def show
    @result = ForecastLookup.new.call(params[:address]) if params.key?(:address)
  end

  private

  def render_error(message, status)
    @error = message
    render :show, status: status, formats: :html
  end
end
