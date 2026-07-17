module Api
  module V1
    class ProvidersController < UsersController
      self.serializer_class = ProviderSerializer
      self.save_webhook = Webhooks::PROVIDER_SAVE
      self.delete_webhook = Webhooks::PROVIDER_DELETE

      private

      def role_slug = Role::PROVIDER

      def with_loaders
        { "services" => ->(record) { record.services.map { |service| raw_row(service) } } }
      end

      def build_record(attrs)
        raise ArgumentError, "No services property provided." unless attrs.key?("services")

        user = super
        @decoded["settings"] ||= {}
        @decoded["settings"]["working_plan"] ||= Setting.get("company_working_plan")
        user
      end

      # EA Providers_model::set_service_ids: re-insert the join rows.
      def apply_links(record)
        return unless @decoded.key?("services")

        record.provider_service_links.delete_all
        Array(@decoded["services"]).each do |service_id|
          ServiceProviderLink.create!(id_users: record.id, id_services: service_id.to_i)
        end
      end
    end
  end
end
