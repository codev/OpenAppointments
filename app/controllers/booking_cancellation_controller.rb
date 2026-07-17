# Public appointment cancellation, port of EA's Booking_cancellation controller.
class BookingCancellationController < ApplicationController
  layout "message"

  # EA excludes booking_cancellation/* from CSRF: the cancellation form posts
  # without a token field (see components/booking_cancellation_frame).
  skip_forgery_protection

  rate_limit to: 5, within: 10.minutes, only: :of,
             with: -> { render_cancellation_error("Too many cancellation attempts. Please try again later.") }

  # POST /booking_cancellation/of/:appointment_hash
  def of
    return head :forbidden if Setting.get("disable_booking") == "1"

    appointment_hash = params[:appointment_hash].to_s
    return head :bad_request unless appointment_hash.match?(/\A[a-zA-Z0-9]+\z/)

    cancellation_reason = params[:cancellation_reason].to_s
    return head :forbidden if cancellation_reason.empty?

    cancellation_reason = helpers.strip_tags(cancellation_reason.strip[0, 1000])

    appointment = Appointment.find_by(booking_hash: appointment_hash)
    return render_appointment_not_found unless appointment

    provider = appointment.provider
    customer = appointment.customer
    service = appointment.service

    company_color = Setting.get("company_color")
    settings = {
      company_name: Setting.get("company_name"),
      company_email: Setting.get("company_email"),
      company_link: Setting.get("company_link"),
      company_color: company_color.present? && company_color != "#ffffff" ? company_color : nil,
      date_format: Setting.get("date_format"),
      time_format: Setting.get("time_format")
    }

    # EA deletes first, then notifies with the already loaded records.
    appointment.destroy!

    Synchronization.appointment_deleted(appointment, provider)
    Notifications.appointment_deleted(appointment, service, provider, customer, settings,
                                      reason: cancellation_reason)
    Webhooks.trigger(Webhooks::APPOINTMENT_DELETE, appointment)

    html_vars(
      page_title: helpers.lang("appointment_cancelled_title"),
      company_color: Setting.get("company_color"),
      google_analytics_code: Setting.get("google_analytics_code"),
      matomo_analytics_url: Setting.get("matomo_analytics_url"),
      matomo_analytics_site_id: Setting.get("matomo_analytics_site_id")
    )

    render :of
  rescue StandardError => e
    Rails.logger.error("Booking Cancellation Exception: #{e.message}")
    render_cancellation_error(e.message)
  end

  private

  def render_appointment_not_found
    html_vars(
      page_title: helpers.lang("appointment_not_found"),
      company_color: Setting.get("company_color"),
      message_title: helpers.lang("appointment_not_found"),
      message_text: helpers.lang("appointment_does_not_exist_in_db"),
      message_icon: helpers.image_path("error.png"),
      google_analytics_code: Setting.get("google_analytics_code"),
      matomo_analytics_url: Setting.get("matomo_analytics_url"),
      matomo_analytics_site_id: Setting.get("matomo_analytics_site_id"),
      display_login_button: Setting.get("display_login_button")
    )
    render "booking/message"
  end

  def render_cancellation_error(message)
    html_vars(
      page_title: helpers.lang("appointment_cancelled_title"),
      company_color: Setting.get("company_color"),
      message_title: helpers.lang("appointment_cancelled_title"),
      message_text: message,
      message_icon: helpers.image_path("error.png"),
      google_analytics_code: Setting.get("google_analytics_code"),
      matomo_analytics_url: Setting.get("matomo_analytics_url"),
      matomo_analytics_site_id: Setting.get("matomo_analytics_site_id"),
      display_login_button: Setting.get("display_login_button")
    )
    render "booking/message"
  end
end
