# Inbound sync (EA's Google::sync): pull a provider's remote Google Calendar events
# within their sync window and reconcile with local records. External events (created
# in Google, not by us) are imported as unavailabilities; remotely cancelled events we
# own are removed locally. Runs from the openappointments:sync cron task.
class CalendarPull
  def initialize(gateway: nil)
    @gateway = gateway || GoogleCalendarGateway.new(redirect_uri: SyncUrls.google_callback)
  end

  def self.run
    result = { providers: 0, imported: 0, removed: 0 }
    User.providers.includes(:settings).find_each do |provider|
      next unless provider.settings&.google_sync

      result[:providers] += 1
      counts = new.sync_provider(provider)
      result[:imported] += counts[:imported]
      result[:removed] += counts[:removed]
    rescue GoogleCalendarGateway::AuthError => e
      Rails.logger.warn("CalendarPull - skipping provider #{provider.id}: #{e.message}")
    end
    result
  end

  def sync_provider(provider)
    settings = provider.settings
    zone = Time.find_zone!(provider.timezone.presence || "UTC")
    now = Time.now.in_time_zone(zone)
    from = now - settings.sync_past_days.to_i.days
    to = now + settings.sync_future_days.to_i.days
    calendar_id = settings.google_calendar.presence || "primary"

    imported = removed = 0
    @gateway.sync_events(provider, calendar_id, from, to).each do |event|
      if event.status == "cancelled"
        removed += 1 if remove_local(provider, event.id)
      elsif import_external(provider, event)
        imported += 1
      end
    end
    { imported: imported, removed: removed }
  end

  private

  # Remove a local record we own whose remote event was cancelled.
  def remove_local(provider, google_event_id)
    record = provider.provider_appointments.find_by(id_google_calendar: google_event_id)
    return false unless record

    record.destroy!
    true
  end

  # Import an event that originated in Google (no local record) as an unavailability.
  # Returns true if a new record was created.
  def import_external(provider, event)
    return false if provider.provider_appointments.exists?(id_google_calendar: event.id)
    return false unless event.start&.date_time && event.end&.date_time

    provider.provider_appointments.create!(
      is_unavailability: true,
      start_datetime: naive(event.start.date_time),
      end_datetime: naive(event.end.date_time),
      notes: event.summary,
      id_google_calendar: event.id,
      book_datetime: Time.now
    )
    true
  end

  # Google returns RFC3339 instants; store the provider-local wall-clock component.
  def naive(datetime)
    Time.parse(datetime.to_s).strftime("%Y-%m-%d %H:%M:%S")
  end
end
