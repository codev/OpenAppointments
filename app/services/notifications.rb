# Email notification orchestrator (EA Notifications library). Decides recipients per
# notification flags, localizes subject per recipient language, converts times into the
# recipient timezone, attaches the ICS stream. Each recipient failure is logged, never
# raised (EA behavior).
module Notifications
  module_function

  def appointment_saved(appointment, service, provider, customer, settings, manage_mode: false)
    ics = IcsFile.stream(appointment, service, provider, customer)

    if customer&.email.present? && Setting.get("customer_notifications") == "1"
      deliver("appointment-saved to customer", appointment) do
        AppointmentMailer.saved(
          appointment: appointment, service: service, provider: provider, customer: customer,
          settings: settings, recipient_email: customer.email, recipient_language: customer.language,
          recipient_timezone: customer.timezone, manage_mode: manage_mode, ics: ics,
          link_path: "/booking/reschedule/#{appointment.booking_hash}", role: :customer
        ).deliver_later
      end
    end

    if provider && notifications_enabled?(provider)
      deliver("appointment-saved to provider", appointment) do
        AppointmentMailer.saved(
          appointment: appointment, service: service, provider: provider, customer: customer,
          settings: settings, recipient_email: provider.email, recipient_language: provider.language,
          recipient_timezone: provider.timezone, manage_mode: manage_mode, ics: ics,
          link_path: "/calendar/reschedule/#{appointment.booking_hash}", role: :provider
        ).deliver_later
      end
    end

    (admin_recipients + secretary_recipients(provider)).each do |recipient|
      deliver("appointment-saved to #{recipient.role.slug}", appointment) do
        AppointmentMailer.saved(
          appointment: appointment, service: service, provider: provider, customer: customer,
          settings: settings, recipient_email: recipient.email, recipient_language: recipient.language,
          recipient_timezone: recipient.timezone, manage_mode: manage_mode, ics: ics,
          link_path: "/calendar/reschedule/#{appointment.booking_hash}", role: :provider
        ).deliver_later
      end
    end
  end

  def appointment_deleted(appointment, service, provider, customer, settings, reason: nil)
    if provider && notifications_enabled?(provider)
      deliver("appointment-deleted to provider", appointment) do
        AppointmentMailer.deleted(
          appointment: appointment, service: service, provider: provider, customer: customer,
          settings: settings, recipient_email: provider.email, recipient_language: provider.language,
          recipient_timezone: provider.timezone, reason: reason
        ).deliver_later
      end
    end

    if customer&.email.present? && Setting.get("customer_notifications") == "1"
      deliver("appointment-deleted to customer", appointment) do
        AppointmentMailer.deleted(
          appointment: appointment, service: service, provider: provider, customer: customer,
          settings: settings, recipient_email: customer.email, recipient_language: customer.language,
          recipient_timezone: customer.timezone, reason: reason
        ).deliver_later
      end
    end

    (admin_recipients + secretary_recipients(provider)).each do |recipient|
      deliver("appointment-deleted to #{recipient.role.slug}", appointment) do
        AppointmentMailer.deleted(
          appointment: appointment, service: service, provider: provider, customer: customer,
          settings: settings, recipient_email: recipient.email, recipient_language: recipient.language,
          recipient_timezone: recipient.timezone, reason: reason
        ).deliver_later
      end
    end
  end

  def notifications_enabled?(user)
    user.settings&.notifications ? true : false
  end

  def admin_recipients
    User.admins.includes(:settings, :role).select { |admin| notifications_enabled?(admin) }
  end

  def secretary_recipients(provider)
    return [] unless provider

    User.secretaries.includes(:settings, :role, :providers).select do |secretary|
      notifications_enabled?(secretary) && secretary.providers.map(&:id).include?(provider.id)
    end
  end

  def deliver(context, appointment)
    yield
  rescue StandardError => e
    Rails.logger.error("Notifications - #{context} failed for appointment #{appointment&.id}: #{e.message}")
  end
end
