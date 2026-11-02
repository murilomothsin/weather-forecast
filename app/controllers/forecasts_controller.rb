class ForecastsController < ApplicationController
  rescue_from(InvalidAddress, AddressNotFound) { |e| render_error(e, :unprocessable_content) }
  rescue_from(ServiceUnavailable) { |e| render_error(e, :service_unavailable) }

  def show
    @result = ForecastLookup.new.call(params[:address]) if params.key?(:address)
  end

  private

  def render_error(error, status)
    @error = error.message
    render :show, status: status
  end
end
