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

    first = BookingWindows.business_today
    last = BookingWindows.last_bookable_date
    engine = Availability::Engine.new
    engine.preload(providers, first, last)
    window = {}
    (first..last).each do |date|
      key = date.strftime("%Y-%m-%d")
      hours = providers.flat_map do |provider|
        engine.available_hours(key, service, provider, exclude_appointment_id: exclude_appointment_id)
      end.uniq.sort
      window[key] = hours if hours.any?
    end
    window
  end

  # No bookable hour anywhere in the window: for the service with any of its
  # providers, or for every service the provider offers.
  def self.fully_booked?(service: nil, provider: nil)
    if service
      build(service, provider&.id || BookingPayloads::ANY_PROVIDER).empty?
    else
      provider.services.none? { |offered| build(offered, provider.id).any? }
    end
  end
end
