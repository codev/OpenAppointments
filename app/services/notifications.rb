# Notification dispatch orchestrator. Appointment events select the matching
# Notification templates; each template fans out to its audiences over its
# ticked, enabled channels as Message rows delivered by MessageDeliveryJob.
# Recipient failures are logged, never raised (EA behaviour).
module Notifications
  CANCELLED_STATUS = "Cancelled".freeze
  NO_SHOW_STATUS = "No Show".freeze

  module_function

  # settings param kept for call-site compatibility; company data now comes from
  # Setting directly.
  def appointment_saved(appointment, service, provider, customer, _settings = nil,
                        manage_mode: false, previous_status: nil)
    trigger = save_trigger(appointment, manage_mode, previous_status)
    dispatch(trigger, appointment, service, provider, customer)
  end

  def appointment_deleted(appointment, service, provider, customer, _settings = nil, reason: nil)
    dispatch(:cancelled, appointment, service, provider, customer, reason: reason)
  end

  def save_trigger(appointment, manage_mode, previous_status)
    status = appointment.status.to_s
    if previous_status && status != previous_status.to_s
      return :cancelled if status == CANCELLED_STATUS
      return :missed if status == NO_SHOW_STATUS
    end
    manage_mode ? :updated : :created
  end

  def dispatch(trigger, appointment, service, provider, customer, reason: nil)
    return unless Messaging.enabled?

    Notification.for_trigger(trigger).find_each do |notification|
      deliver_notification(notification, appointment, service, provider, customer, reason: reason)
    end
  end

  # Due coming-up notifications (ReminderScanJob / openappointments:reminders).
  def scan_coming_up(now = Time.current)
    return unless Messaging.enabled?

    Notification.coming_up.find_each do |notification|
      due_appointments(notification, now).each do |appointment|
        next unless NotificationDispatch.record!(notification, appointment)

        deliver_notification(notification, appointment,
                             appointment.service, appointment.provider, appointment.customer)
      end
    end
  end

  def due_appointments(notification, now)
    horizon = now + notification.lead_days.days + notification.lead_hours.hours + 1.day
    Appointment.appointments
               .where(start_datetime: now..horizon)
               .where.not(status: [ CANCELLED_STATUS, NO_SHOW_STATUS ])
               .includes(:service, :provider, :customer)
               .select { |appointment| send_at(notification, appointment) <= now }
  end

  def send_at(notification, appointment)
    start_at = appointment.start_datetime
    if notification.lead_mode == "day_at"
      date = start_at.to_date - notification.lead_days
      hour, minute = notification.send_time.split(":").map(&:to_i)
      Time.zone.local(date.year, date.month, date.day, hour, minute)
    else
      start_at - notification.lead_days.days - notification.lead_hours.hours
    end
  end

  def deliver_notification(notification, appointment, service, provider, customer, reason: nil)
    recipients(notification, provider, customer).each do |user, audience|
      channels = Array(notification.channels) & Messaging.enabled_channel_keys
      channels.each do |channel_key|
        deliver("#{notification.title} to #{audience}", appointment) do
          queue_message(notification, channel_key, user, audience,
                        appointment, service, provider, customer, reason)
        end
      end
    end
  end

  # [user, audience] pairs. The admins audience keeps EA's fan-out: every admin
  # plus the secretaries the provider is assigned to.
  def recipients(notification, provider, customer)
    pairs = []
    pairs << [ customer, "customer" ] if customer && notification.audience?(:customer) && contactable?(customer)
    pairs << [ provider, "provider" ] if provider && notification.audience?(:provider)
    if notification.audience?(:admins)
      User.admins.each { |admin| pairs << [ admin, "admins" ] }
      secretaries_for(provider).each { |secretary| pairs << [ secretary, "admins" ] }
    end
    pairs
  end

  # The 10to8 import stores withdrawn consent as do_not_contact=yes in notes
  # (GDPR); those customers get no notifications on any channel.
  def contactable?(customer)
    !customer.notes.to_s.include?("do_not_contact=yes")
  end

  def secretaries_for(provider)
    return [] unless provider

    User.secretaries.includes(:providers).select do |secretary|
      secretary.providers.map(&:id).include?(provider.id)
    end
  end

  def queue_message(notification, channel_key, user, audience, appointment, service, provider, customer, reason)
    adapter = Messaging.channel(channel_key)
    address = adapter.address_for(user)
    return if address.blank?

    link_path = audience == "customer" ? "/booking/reschedule/#{appointment.booking_hash}"
                                       : "/calendar/reschedule/#{appointment.booking_hash}"
    context = Messaging::Template.appointment_context(
      appointment: appointment, service: service, provider: provider, customer: customer,
      recipient_timezone: user.timezone, reason: reason, link_path: link_path
    )
    short = Messaging::Template.render(notification.short_text, context)
    long = Messaging::Template.render(notification.long_text, context)

    if adapter.supports_long_text?
      subject = short.presence ||
                Messaging::Template.render(Messaging.email_subject_template, context)
      body = long.presence || short
    else
      subject = nil
      body = short.presence || long
    end
    return if body.blank?

    message = Message.create!(
      direction: "outgoing", channel: channel_key, audience: audience, to_address: address,
      customer_id: audience == "customer" ? user.id : nil,
      appointment_id: appointment&.id, notification_id: notification.id,
      subject: subject, body: body, status: "queued"
    )
    MessageDeliveryJob.perform_later(message.id)
  end

  def deliver(context, appointment)
    yield
  rescue StandardError => e
    Rails.logger.error("Notifications - #{context} failed for appointment #{appointment&.id}: #{e.message}")
  end
end
