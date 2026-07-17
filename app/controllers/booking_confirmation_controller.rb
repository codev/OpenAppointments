# Booking success page, port of EA's Booking_confirmation controller.
class BookingConfirmationController < ApplicationController
  include EmbeddableFrame
  layout "message"

  # GET /booking_confirmation/of/:appointment_hash
  def of
    appointment = Appointment.find_by(booking_hash: params[:appointment_hash])
    return redirect_to "/" unless appointment # The appointment does not exist.

    html_vars(
      page_title: helpers.lang("success"),
      company_color: Setting.get("company_color"),
      google_analytics_code: Setting.get("google_analytics_code"),
      matomo_analytics_url: Setting.get("matomo_analytics_url"),
      matomo_analytics_site_id: Setting.get("matomo_analytics_site_id"),
      add_to_google_url: add_to_google_url(appointment),
      display_add_to_google_calendar: Setting.get("display_add_to_google_calendar", "1")
    )
  end

  private

  # EA Google_sync::get_add_to_google_url: a calendar.google.com "add event" template link.
  def add_to_google_url(appointment)
    provider = appointment.provider
    customer = appointment.customer
    zone = Time.find_zone!(provider&.timezone.presence || "UTC")
    dates = [ appointment.start_datetime, appointment.end_datetime ].map { |dt|
      zone.parse(dt.strftime("%Y-%m-%d %H:%M:%S")).utc.strftime("%Y%m%dT%H%M%SZ")
    }.join("/")

    query = URI.encode_www_form(
      action: "TEMPLATE",
      text: appointment.service&.name,
      dates: dates,
      location: Setting.get("company_name"),
      details: "View/Change Appointment: #{request.base_url}/booking/reschedule/#{appointment.booking_hash}"
    )

    # Append each guest separately (provider first, then customer when present).
    [ provider&.email, customer&.email ].compact_blank.each do |email|
      query += "&add=#{ERB::Util.url_encode(email)}"
    end

    "https://calendar.google.com/calendar/render?#{query}"
  end
end
