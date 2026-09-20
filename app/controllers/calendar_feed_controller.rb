# One way calendar feed: a provider's calendar as ICS behind a secret link, and
# the endpoint that makes or resets that link.
class CalendarFeedController < ApplicationController
  before_action :require_session, only: :link

  # GET /calendar/feed/:token.ics, fetched by the provider's calendar app.
  def show
    settings = UserSetting.find_by(calendar_feed_token: params[:token].to_s.presence)
    provider = settings && User.providers.find_by(id: settings.id_users)
    return head :not_found unless provider

    response.headers["Cache-Control"] = "no-cache"
    send_data CalendarFeed.ics(provider), type: "text/calendar", disposition: "inline"
  end

  # POST /calendar/feed_link (provider_id, reset): the link, made on first use.
  def link
    provider = User.providers.find(params.require(:provider_id))
    return head :forbidden unless can?(:edit, :users) || session[:user_id].to_i == provider.id

    settings = provider.settings || provider.create_settings!
    if settings.calendar_feed_token.blank? || params[:reset].present?
      settings.update!(calendar_feed_token: SecureRandom.alphanumeric(32))
    end
    render json: { url: "#{request.base_url}/calendar/feed/#{settings.calendar_feed_token}.ics" }
  end
end
