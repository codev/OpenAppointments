# A booking paid through a checkout method: register holds the slot and starts
# the hosted payment, the return page settles it, and a payment that is not
# completed releases the slot. Nothing is announced until the booking is paid.
module BookingPayment
  module_function

  # Stripe's minimum is 30 minutes on its own clock, so the session gets a
  # minute's grace.
  CHECKOUT_EXPIRY = 31.minutes
  # The sweep waits this much longer, so the return page gets to settle first.
  SWEEP_GRACE = 5.minutes

  # An unpaid booking through a checkout method.
  def checkout?(appointment)
    appointment.unpaid? && (method_of(appointment)&.checkout? || false)
  end

  # Starts the payment, keeps the session id and answers the page to send the
  # customer to. The provider sends the customer back to return_url whether
  # they pay or go back.
  def start(appointment, return_url:)
    session = method_of(appointment).create_checkout_session(appointment, success_url: return_url, cancel_url: return_url,
                                                                           expires_at: CHECKOUT_EXPIRY.from_now)
    appointment.update!(payment_reference: session["id"])
    session["url"]
  end

  # Asks the provider where the payment stands and acts on it: a paid booking
  # is marked and announced, an expired one released. Answers [state, url], the
  # url being the payment page while the session is still open.
  def settle(appointment)
    outcome = method_of(appointment).checkout_state(appointment.payment_reference)
    case outcome[:state]
    when :paid then confirm_paid(appointment, outcome[:payment_id])
    when :expired then release(appointment)
    end
    [ outcome[:state], outcome[:url] ]
  end

  # Settles every held booking whose session has had time to expire, so a
  # payment the webhook missed is still marked and an abandoned booking still
  # released. Answers how many were settled; a provider error skips that one.
  def sweep(now = Time.current)
    checkout_keys = Payments.all.select(&:checkout?).map(&:key)
    held = Appointment.appointments.active
                      .where(paid_at: nil, payment_method: checkout_keys)
                      .where.not(payment_reference: [ nil, "" ])
                      .where(book_datetime: ...(now - CHECKOUT_EXPIRY - SWEEP_GRACE))
    held.count do |appointment|
      settle(appointment)
      true
    rescue StandardError => e
      Rails.logger.error("BookingPayment - sweeping appointment #{appointment.id} failed: #{e.message}")
      false
    end
  end

  # Idempotent: the return page and a webhook may both report the payment.
  def confirm_paid(appointment, reference)
    return if appointment.paid_at

    appointment.mark_paid!(reference: reference)
    Bookings.announce(appointment)
  end

  # Cancel booking on the pending page: the slot is released and the session
  # closed, so a payment page left open in another tab cannot pay for it.
  def abandon(appointment)
    release(appointment)
    method_of(appointment).expire_checkout_session(appointment.payment_reference)
  rescue StandardError => e
    Rails.logger.error("BookingPayment - expiring session #{appointment.payment_reference} failed: #{e.message}")
  end

  # Nothing was announced for a held booking, so nobody is told it is cancelled.
  def release(appointment)
    appointment.cancel! unless appointment.frees_slot?
  end

  def method_of(appointment) = Payments.find(appointment.payment_method)
end
