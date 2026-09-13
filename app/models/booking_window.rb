# Every bookable hour in the whole booking window for a service and provider
# (or any provider), keyed by date. Sent to the time step in one piece so
# browsing days needs no further requests.
class BookingWindow
  # { "YYYY-MM-DD" => [ "HH:MM", ... ] }, empty days omitted.
  def self.build(service, provider_id, exclude_appointment_id: nil)
    providers =
      if provider_id.to_s == BookingPayloads::ANY_PROVIDER
        BookingPayloads.providers_for_service(service.id).to_a
      else
        [ User.providers.find(provider_id) ]
      end

    horizon = Setting.get("future_booking_limit", "90").to_i
    engine = Availability::Engine.new
    engine.preload(providers, Date.current, Date.current + horizon.days)
    window = {}
    (Date.current..Date.current + horizon.days).each do |date|
      key = date.strftime("%Y-%m-%d")
      hours = providers.flat_map do |provider|
        engine.available_hours(key, service, provider, exclude_appointment_id: exclude_appointment_id)
      end.uniq.sort
      window[key] = hours if hours.any?
    end
    window
  end
end
