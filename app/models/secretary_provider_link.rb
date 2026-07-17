class SecretaryProviderLink < ApplicationRecord
  self.table_name = "secretaries_providers"
  self.primary_key = [ :id_users_secretary, :id_users_provider ]

  belongs_to :secretary, class_name: "User", foreign_key: :id_users_secretary, inverse_of: :secretary_provider_links
  belongs_to :provider, class_name: "User", foreign_key: :id_users_provider
end
