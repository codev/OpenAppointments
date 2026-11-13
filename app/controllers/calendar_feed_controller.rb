# One way calendar feed: a provider's calendar as ICS behind a secret link, and
# the endpoint that makes or resets that link.
class CalendarFeedController < ApplicationController
  before_action :require_session, only: [ :link, :window ]

  # How far the feed reaches, in days each side of today.
  WINDOW_RANGE = (0..3650)

  # GET /calendar/feed/:token.ics, fetched by the provider's calendar app.
  def show
    settings = UserSetting.find_by(calendar_feed_token: params[:token].to_s.presence)
    provider = settings && User.providers.find_by(id: settings.id_users)
    return head :not_found unless provider

    response.headers["Cache-Control"] = "no-cache"
    send_data CalendarFeed.ics(provider), type: "text/calendar", disposition: "inline"
  end

  # POST /calendar/feed_link (provider_id, reset): the link, made on first use,
  # with the window the feed covers.
  def link
    settings = managed_settings
    return head :forbidden unless settings

    if settings.calendar_feed_token.blank? || params[:reset].present?
      settings.update!(calendar_feed_token: SecureRandom.alphanumeric(32))
    end
    render json: { url: "#{request.base_url}/calendar/feed/#{settings.calendar_feed_token}.ics", **window_of(settings) }
  end

  # POST /calendar/feed_window (provider_id, past_days, future_days): how far
  # back and ahead the feed reaches, clamped to whole days.
  def window
    settings = managed_settings
    return head :forbidden unless settings

    settings.update!(sync_past_days: params[:past_days].to_i.clamp(WINDOW_RANGE),
                     sync_future_days: params[:future_days].to_i.clamp(WINDOW_RANGE))
    render json: window_of(settings)
  end

  private

  # The settings row of the provider in the request, when the session may
  # manage it: an editor of users, or the provider themselves.
  def managed_settings
    provider = User.providers.find(params.require(:provider_id))
    return unless can?(:edit, :users) || session[:user_id].to_i == provider.id

    provider.settings || provider.create_settings!
  end

  def window_of(settings)
    { past_days: settings.sync_past_days.to_i, future_days: settings.sync_future_days.to_i }
  end
end
