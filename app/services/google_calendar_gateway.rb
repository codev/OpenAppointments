require "google/apis/calendar_v3"
require "googleauth"
require "signet/oauth_2/client"

# Google Calendar gateway, port of EA's Google_sync library. Wraps OAuth (auth URL,
# code exchange, token refresh) and event add/update/delete. Times are provider-local
# wall-clock, emitted with the provider timezone (RFC3339 / all-day date), as in EA.
class GoogleCalendarGateway
  Calendar = Google::Apis::CalendarV3
  SCOPE = "https://www.googleapis.com/auth/calendar".freeze
  AuthError = Class.new(StandardError)

  def initialize(redirect_uri:)
    @redirect_uri = redirect_uri
  end

  # OAuth ---------------------------------------------------------------------

  def authorization_url(state: nil)
    client = oauth_client
    client.state = state if state
    "#{client.authorization_uri(access_type: 'offline', prompt: 'consent')}&max_auth_age=0"
  end

  # Exchange the auth code for tokens; returns the token hash to store on the provider.
  def exchange_code(code)
    client = oauth_client(code: code)
    client.fetch_access_token!
    {
      "access_token" => client.access_token,
      "refresh_token" => client.refresh_token,
      "expires_in" => client.expires_in,
      "created" => Time.now.to_i
    }
  rescue Signet::AuthorizationError => e
    raise AuthError, "Google authentication failed: #{e.message}"
  end

  # A calendar service authorized for a provider's stored token (refreshes it).
  def service_for(provider)
    token = provider_token(provider)
    client = oauth_client(refresh_token: token["refresh_token"])
    client.refresh!
    service = Calendar::CalendarService.new
    service.authorization = client
    service
  rescue Signet::AuthorizationError => e
    raise AuthError, "Google token refresh failed for provider #{provider.id}: #{e.message}"
  end

  # Events --------------------------------------------------------------------

  def add_appointment(provider, appointment, service, customer, company_name)
    event = build_event(appointment, provider, service, customer, company_name)
    service_for(provider).insert_event(calendar_id(provider), event)
  end

  def update_appointment(provider, appointment, service, customer, company_name)
    event = build_event(appointment, provider, service, customer, company_name)
    service_for(provider).update_event(calendar_id(provider), appointment.id_google_calendar, event)
  end

  def delete_appointment(provider, google_event_id)
    service_for(provider).delete_event(calendar_id(provider), google_event_id)
  rescue Google::Apis::ClientError => e
    raise unless e.status_code == 404 # already gone
  end

  def sync_events(provider, calendar_id, from, to)
    service_for(provider).list_events(calendar_id, time_min: from.iso8601, time_max: to.iso8601,
                                                    single_events: true, show_deleted: true).items
  end

  def calendars(provider)
    service_for(provider).list_calendar_lists.items.map { |cal| { "id" => cal.id, "summary" => cal.summary } }
  end

  # Pure event construction (EA add_appointment), testable without the API.
  def build_event(appointment, provider, service, customer, company_name)
    tzid = provider.timezone.presence || "UTC"
    Calendar::Event.new(
      summary: service&.name.presence || "Unavailable",
      description: appointment.notes,
      location: appointment.location.presence || company_name,
      start: event_datetime(appointment.start_datetime, tzid),
      end: event_datetime(appointment.end_datetime, tzid),
      attendees: attendees(provider, customer)
    )
  end

  private

  def event_datetime(time, tzid)
    Calendar::EventDateTime.new(date_time: time.strftime("%Y-%m-%dT%H:%M:%S"), time_zone: tzid)
  end

  def attendees(provider, customer)
    list = [ Calendar::EventAttendee.new(display_name: provider.full_name, email: provider.email) ]
    if customer&.email.present?
      list << Calendar::EventAttendee.new(display_name: customer.full_name, email: customer.email)
    end
    list
  end

  def calendar_id(provider)
    provider.settings&.google_calendar.presence || "primary"
  end

  def provider_token(provider)
    raw = provider.settings&.google_token
    raise AuthError, "No Google token stored for provider #{provider.id}" if raw.blank?

    JSON.parse(raw)
  end

  def oauth_client(code: nil, refresh_token: nil)
    Signet::OAuth2::Client.new(
      authorization_uri: "https://accounts.google.com/o/oauth2/auth",
      token_credential_uri: "https://oauth2.googleapis.com/token",
      client_id: Setting.get("google_client_id"),
      client_secret: Setting.get("google_client_secret"),
      redirect_uri: @redirect_uri,
      scope: SCOPE,
      code: code,
      refresh_token: refresh_token
    )
  end
end
