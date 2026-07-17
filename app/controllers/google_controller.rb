# Google Calendar OAuth flow, port of EA's Google controller. Connects a provider's
# Google account, lists and selects a calendar, and disables sync.
class GoogleController < ApplicationController
  before_action :require_session
  before_action :require_editor_or_self, only: [ :oauth, :select_google_calendar, :disable_provider_sync ]

  # GET /google/oauth/:provider_id
  def oauth
    state = SecureRandom.hex(32)
    session[:oauth_provider_id] = params[:provider_id].to_i
    session[:oauth_state] = state
    redirect_to gateway.authorization_url(state: state), allow_other_host: true
  end

  # GET /google/oauth_callback
  def oauth_callback
    returned_state = params[:state].to_s
    stored_state = session[:oauth_state].to_s
    if returned_state.blank? || stored_state.blank? ||
       !ActiveSupport::SecurityUtils.secure_compare(returned_state, stored_state)
      session[:oauth_state] = nil
      return render plain: "Security validation failed. Please try the Google Calendar sync again.", status: :forbidden
    end
    session[:oauth_state] = nil

    return render plain: "Code authorization failed." if params[:code].blank?

    token = gateway.exchange_code(params[:code])
    provider = User.providers.find_by(id: session[:oauth_provider_id])
    return render plain: "Sync provider id not specified." unless provider

    settings = provider.settings || provider.create_settings!
    settings.update!(google_sync: true, google_token: token.to_json, google_calendar: "primary")
    session[:oauth_provider_id] = nil

    render html: popup_close_script.html_safe # rubocop:disable Rails/OutputSafety
  rescue GoogleCalendarGateway::AuthError => e
    render plain: e.message, status: :bad_request
  end

  # POST /google/get_google_calendars
  def get_google_calendars
    provider = User.providers.find(params.require(:provider_id))
    return render json: { success: false } unless provider.settings&.google_sync

    render json: gateway.calendars(provider)
  rescue StandardError => e
    json_exception(e)
  end

  # POST /google/select_google_calendar
  def select_google_calendar
    provider = User.providers.find(params.require(:provider_id))
    provider.settings.update!(google_calendar: params.require(:calendar_id))
    render json: { success: true }
  rescue StandardError => e
    json_exception(e)
  end

  # POST /google/disable_provider_sync
  def disable_provider_sync
    provider = User.providers.find(params.require(:provider_id))
    provider.settings&.update!(google_sync: false, google_token: nil)
    provider.provider_appointments.where.not(id_google_calendar: nil).update_all(id_google_calendar: nil)
    render json: { success: true }
  rescue StandardError => e
    json_exception(e)
  end

  private

  def gateway
    GoogleCalendarGateway.new(redirect_uri: google_oauth_callback_url)
  end

  def require_editor_or_self
    provider_id = params[:provider_id].to_i
    return if can?(:edit, :users) || session[:user_id].to_i == provider_id

    head :forbidden
  end

  def popup_close_script
    '<script>window.opener && window.opener.postMessage("oauth_success", window.location.origin); ' \
      "window.close();</script>"
  end
end
