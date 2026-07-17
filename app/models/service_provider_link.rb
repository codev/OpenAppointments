class ServiceProviderLink < ApplicationRecord
  self.table_name = "services_providers"
  self.primary_key = [ :id_users, :id_services ]

  belongs_to :provider, class_name: "User", foreign_key: :id_users, inverse_of: :provider_service_links
  belongs_to :service, foreign_key: :id_services, inverse_of: :provider_links
end
