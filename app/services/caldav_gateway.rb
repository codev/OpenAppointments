# CalDAV gateway, port of EA's Caldav_sync library. Puts/deletes an appointment's ICS
# at {caldav_url}/{event_id}.ics using the provider's stored CalDAV credentials.
class CaldavGateway
  AuthError = Class.new(StandardError)

  # Save an event; returns the CalDAV event id (its ICS UID). Raises on transport error.
  def save_appointment(provider, appointment, service, customer)
    event_id = appointment.id_caldav_calendar.presence || IcsFile.uid_for(appointment.id)
    ics = IcsFile.stream(appointment, service, provider, customer)
    put_event(provider, event_id, ics)
    event_id
  end

  def delete_event(provider, caldav_event_id)
    request(provider, Net::HTTP::Delete, event_uri(provider, caldav_event_id))
  end

  def test_connection(url, username, password)
    uri = URI.parse(url)
    http = build_http(uri)
    req = Net::HTTP::Options.new(uri.request_uri)
    req.basic_auth(username, password)
    response = http.request(req)
    raise AuthError, "CalDAV connection failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    true
  end

  private

  def put_event(provider, event_id, ics)
    uri = event_uri(provider, event_id)
    request(provider, Net::HTTP::Put, uri) do |req|
      req["Content-Type"] = "text/calendar"
      req.body = ics
    end
  end

  def request(provider, verb_class, uri)
    settings = provider.settings
    http = build_http(uri)
    req = verb_class.new(uri.request_uri)
    req.basic_auth(settings.caldav_username, settings.caldav_password)
    yield req if block_given?

    response = http.request(req)
    unless response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPNoContent)
      raise "CalDAV request failed: HTTP #{response.code}"
    end

    response
  end

  def event_uri(provider, event_id)
    base = provider.settings.caldav_url.to_s.chomp("/")
    URI.parse("#{base}/#{event_id}.ics")
  end

  def build_http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 15
    http
  end
end
