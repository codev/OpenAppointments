# Payload shapes the ported booking JS expects (EA model rows serialized to JSON).
module BookingPayloads
  ANY_PROVIDER = "any-provider".freeze

  module_function

  # EA get_available_services(true): non-private services with >=1 provider, category joined.
  def available_services
    Service.available.joins(:provider_links).distinct
           .with_attached_picture
           .left_joins(:category)
           .where(service_categories: { is_hidden: [ nil, false ] })
           .display_order
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
      "service_category_id" => service.try(:service_category_id),
      "booking_slug" => service.booking_slug,
      "picture_url" => EaRows.picture_url(service)
    }
  end

  # A single service loaded with the category aliases service_payload expects.
  def service_row(service_id)
    Service.with_attached_picture.left_joins(:category)
           .select("services.*", "service_categories.name AS service_category_name",
                   "service_categories.id AS service_category_id")
           .find_by(id: service_id)
  end

  # Categories of the available services (cards display mode), EA order.
  def available_categories
    category_ids = Service.available.joins(:provider_links).distinct.pluck(:id_service_categories).compact
    ServiceCategory.where(id: category_ids, is_hidden: false)
                   .with_attached_picture.display_order.map { |category| category_payload(category) }
  end

  def category_payload(category)
    { "id" => category.id, "name" => category.name, "description" => category.description,
      "picture_url" => EaRows.picture_url(category) }
  end

  # EA get_available_providers(true) reduced to allowed_provider_fields.
  def available_providers
    User.providers.where(is_private: false)
        .joins(:provider_service_links).distinct
        .display_order
        .with_attached_picture
        .includes(:services)
        .map { |provider| provider_payload(provider) }
  end

  def provider_payload(provider)
    {
      "id" => provider.id, "name" => provider.name,
      "services" => provider.services.map(&:id), "timezone" => provider.timezone,
      "booking_slug" => provider.booking_slug, "is_private" => provider.is_private,
      "about" => provider.about, "services_description" => provider.services_description,
      "picture_url" => EaRows.picture_url(provider)
    }
  end

  # Records reachable only through a direct booking link: a slug that matches a
  # record missing from the public payloads (private, or in a hidden category)
  # is added along with the counterpart records and categories needed to book
  # it. Associated records get their slug nulled so one link cannot expose
  # another record's link; slugs of already-public records add nothing.
  def slug_additions(service_slug, provider_slug, known_service_ids:, known_provider_ids:)
    services = {}
    providers = {}

    service = service_slug.present? ? Service.find_by(booking_slug: service_slug.to_s) : nil
    if service && !known_service_ids.include?(service.id)
      services[service.id] = service_payload(service_row(service.id))
      service.providers.each do |provider|
        next if known_provider_ids.include?(provider.id)
        providers[provider.id] = provider_payload(provider).merge("booking_slug" => nil)
      end
    end

    provider = provider_slug.present? ? User.providers.find_by(booking_slug: provider_slug.to_s) : nil
    if provider && !known_provider_ids.include?(provider.id)
      providers[provider.id] = provider_payload(provider)
      provider.services.each do |linked|
        next if known_service_ids.include?(linked.id) || services.key?(linked.id)
        services[linked.id] = service_payload(service_row(linked.id)).merge("booking_slug" => nil)
      end
    end

    { services: services.values, providers: providers.values }
  end

  # Providers (AR records) that offer the service, non-private, EA order.
  def providers_for_service(service_id)
    User.providers.where(is_private: false)
        .joins(:provider_service_links)
        .where(services_providers: { id_services: service_id })
        .order(:name, :email)
        .distinct
  end
end
