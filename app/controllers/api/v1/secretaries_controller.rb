module Api
  module V1
    class SecretariesController < UsersController
      self.serializer_class = SecretarySerializer
      self.save_webhook = Webhooks::SECRETARY_SAVE
      self.delete_webhook = Webhooks::SECRETARY_DELETE

      private

      def role_slug = Role::SECRETARY

      def build_record(attrs)
        raise ArgumentError, "No providers property provided." unless attrs.key?("providers")

        super
      end

      # EA Secretaries_model::save_provider_ids: re-insert the join rows.
      def apply_links(record)
        return unless @decoded.key?("providers")

        record.secretary_provider_links.delete_all
        Array(@decoded["providers"]).each do |provider_id|
          SecretaryProviderLink.create!(id_users_secretary: record.id, id_users_provider: provider_id.to_i)
        end
      end
    end
  end
end
