# The customer's return from a hosted payment page, and the way out of one.
class BookingPaymentController < ApplicationController
  layout "message"

  before_action :find_appointment

  # GET /booking_payment/of/:appointment_hash: the payment provider sends the
  # customer here after paying and when they go back without paying.
  def of
    return redirect_to confirmation_path unless BookingPayment.checkout?(@appointment)
    return render_status(:expired) if @appointment.frees_slot?

    state, url = BookingPayment.settle(@appointment)
    case state
    when :paid then redirect_to confirmation_path
    when :open then render_status(:pending, try_again_url: url)
    else render_status(:expired)
    end
  rescue StandardError => e
    Rails.logger.error("Booking Payment Exception: #{e.message}")
    render_status(:pending, alert: helpers.lang("payments_checkout_failed"))
  end

  # POST /booking_payment/abandon/:appointment_hash: Cancel booking on the pending page.
  def abandon
    return redirect_to confirmation_path unless BookingPayment.checkout?(@appointment)
    return render_status(:expired) if @appointment.frees_slot?

    BookingPayment.abandon(@appointment)
    render_status(:abandoned)
  end

  private

  def find_appointment
    @appointment = Appointment.find_by(booking_hash: params[:appointment_hash].to_s)
    redirect_to "/" unless @appointment
  end

  def confirmation_path = booking_confirmation_path(appointment_hash: @appointment.booking_hash)

  # pending: the session is open, with Try again and Cancel booking. expired
  # and abandoned: the slot is released, with Book again.
  def render_status(status, try_again_url: nil, alert: nil)
    titles = { pending: "payments_not_completed_title", expired: "payments_expired_title", abandoned: "appointment_cancelled_title" }
    texts = { pending: "payments_not_completed_text", expired: "payments_expired_text", abandoned: "payments_abandoned_text" }
    html_vars(
      page_title: helpers.lang(titles[status]),
      message_title: helpers.lang(titles[status]),
      message_text: helpers.lang(texts[status]),
      status: status,
      alert: alert,
      try_again_url: try_again_url,
      appointment_hash: @appointment.booking_hash,
      company_color: Setting.get("company_color"),
      legal_notice_url: Setting.get("legal_notice_url"),
      imprint_url: Setting.get("imprint_url"),
      google_analytics_code: Setting.get("google_analytics_code"),
      matomo_analytics_url: Setting.get("matomo_analytics_url"),
      matomo_analytics_site_id: Setting.get("matomo_analytics_site_id")
    )
    render :status
  end
end
