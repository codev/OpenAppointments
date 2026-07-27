module Api
  module V1
    class AssistantsController < UsersController
      self.serializer_class = AssistantSerializer
      self.save_webhook = Webhooks::ASSISTANT_SAVE
      self.delete_webhook = Webhooks::ASSISTANT_DELETE

      private

      def role_slug = Role::ASSISTANT

      def with_loaders
        { "providers" => ->(record) { record.providers.map { |provider| raw_row(provider) } } }
      end

      def build_record(attrs)
        raise ArgumentError, "No providers property provided." unless attrs.key?("providers")

        super
      end

      # EA Assistants_model::save_provider_ids: re-insert the join rows.
      def apply_links(record)
        return unless @decoded.key?("providers")

        record.assistant_provider_links.delete_all
        Array(@decoded["providers"]).each do |provider_id|
          AssistantProviderLink.create!(id_users_assistant: record.id, id_users_provider: provider_id.to_i)
        end
      end
    end
  end
end
