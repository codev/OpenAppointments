module Api
  module V1
    # EA availabilities API: GET providerId, serviceId, date (defaults to today).
    class AvailabilitiesController < BaseController
      def get
        provider = User.providers.find(params[:providerId])
        service = Service.find(params[:serviceId])
        date = params[:date].presence || Date.today.strftime("%Y-%m-%d")

        render json: Availability::Engine.new.available_hours(date, service, provider)
      end
    end
  end
end
