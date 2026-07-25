class AssistantProviderLink < ApplicationRecord
  self.table_name = "assistants_providers"
  self.primary_key = [ :id_users_assistant, :id_users_provider ]

  belongs_to :assistant, class_name: "User", foreign_key: :id_users_assistant, inverse_of: :assistant_provider_links
  belongs_to :provider, class_name: "User", foreign_key: :id_users_provider
end
