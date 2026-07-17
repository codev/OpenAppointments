# Payload shapes the ported booking JS expects (EA model rows serialized to JSON).
module BookingPayloads
  ANY_PROVIDER = "any-provider".freeze

  module_function

  # EA get_available_services(true): non-private services with >=1 provider, category joined.
  def available_services
    Service.available.joins(:provider_links).distinct
           .left_joins(:category)
           .order(:name)
           .select("services.*", "service_categories.name AS service_category_name",
                   "service_categories.id AS service_category_id")
           .map { |service| service_payload(service) }
  end

  def service_payload(service)
    {
      "id" => service.id, "name" => service.name, "duration" => service.duration,
      "price" => service.price&.to_f, "currency" => service.currency,
      "description" => service.description, "location" => service.location,
      "color" => service.color, "slot_interval" => service.slot_interval,
      "attendants_number" => service.attendants_number, "is_private" => service.is_private,
      "id_service_categories" => service.id_service_categories,
      "service_category_name" => service.try(:service_category_name),
      "service_category_id" => service.try(:service_category_id)
    }
  end

  # EA get_available_providers(true) reduced to allowed_provider_fields.
  def available_providers
    User.providers.where(is_private: false)
        .joins(:provider_service_links).distinct
        .order(:first_name, :last_name, :email)
        .includes(:services)
        .map do |provider|
      {
        "id" => provider.id, "first_name" => provider.first_name, "last_name" => provider.last_name,
        "services" => provider.services.map(&:id), "timezone" => provider.timezone
      }
    end
  end

  # Providers (AR records) that offer the service, non-private, EA order.
  def providers_for_service(service_id)
    User.providers.where(is_private: false)
        .joins(:provider_service_links)
        .where(services_providers: { id_services: service_id })
        .order(:first_name, :last_name, :email)
        .distinct
  end
end
