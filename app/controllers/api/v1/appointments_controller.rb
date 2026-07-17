module Api
  module V1
    class AppointmentsController < ResourceController
      self.serializer_class = AppointmentSerializer

      # EA destroy deletes first, then notifies (data captured beforehand).
      def destroy
        record = base_scope.find_by(id: params[:id])
        return head :not_found unless record

        service = record.service
        provider = record.provider
        customer = record.customer
        record.destroy!

        Synchronization.appointment_deleted(record, provider)
        Notifications.appointment_deleted(record, service, provider, customer, notification_settings)
        Webhooks.trigger(Webhooks::APPOINTMENT_DELETE, record)
        head :no_content
      end

      private

      def base_scope = Appointment.appointments

      def build_record(attrs)
        decoded = serializer_class.decode(attrs)
        appointment = Appointment.new(decoded)
        appointment.is_unavailability = false
        appointment.book_datetime ||= Time.now
        ensure_end_datetime(appointment)
        appointment
      end

      def apply_update(record, attrs)
        record.assign_attributes(serializer_class.decode(attrs))
        ensure_end_datetime(record)
      end

      def persist!(record)
        manage_mode = record.persisted?
        record.save!
        run_side_effects(record, manage_mode: manage_mode)
      end

      def trigger_save_webhook(record); end # fired inside run_side_effects

      def ensure_end_datetime(appointment)
        return if appointment.end_datetime.present?
        return unless appointment.start_datetime && appointment.id_services

        service = Service.find_by(id: appointment.id_services)
        return unless service&.duration

        appointment.end_datetime = appointment.start_datetime + service.duration.to_i * 60
      end

      def run_side_effects(appointment, manage_mode:)
        service = appointment.service
        provider = appointment.provider
        customer = appointment.customer
        settings = notification_settings

        Synchronization.appointment_saved(appointment, service, provider, customer, settings)
        Notifications.appointment_saved(appointment, service, provider, customer, settings, manage_mode: manage_mode)
        Webhooks.trigger(Webhooks::APPOINTMENT_SAVE, appointment)
      end

      def with_loaders
        {
          "service" => ->(record) { raw_row(record.service) },
          "provider" => ->(record) { raw_row(record.provider) },
          "customer" => ->(record) { raw_row(record.customer) }
        }
      end

      def extra_filters(scope)
        # EA quirk: a keyword search replaces the where filters entirely
        # (model->search is called instead of model->get).
        return scope if api_keyword

        scope = scope.where("DATE(start_datetime) = ?", params[:date]) if params[:date].present?
        scope = scope.where("DATE(start_datetime) >= ?", params[:from]) if params[:from].present?
        scope = scope.where("DATE(end_datetime) <= ?", params[:till]) if params[:till].present?
        scope = scope.where(id_services: params[:serviceId]) if params[:serviceId].present?
        scope = scope.where(id_users_provider: params[:providerId]) if params[:providerId].present?
        scope = scope.where(id_users_customer: params[:customerId]) if params[:customerId].present?
        scope
      end

      def notification_settings
        company_color = Setting.get("company_color")
        {
          company_name: Setting.get("company_name"),
          company_email: Setting.get("company_email"),
          company_link: Setting.get("company_link"),
          company_color: company_color.present? && company_color != "#ffffff" ? company_color : nil,
          date_format: Setting.get("date_format"),
          time_format: Setting.get("time_format")
        }
      end
    end
  end
end
