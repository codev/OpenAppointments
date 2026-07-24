module TenToEight
  # Port of import/load_to_ea.py, writing straight to the models. Matches existing
  # records (categories/services by name, providers by email, customers by email or
  # name+phone) so re-runs do not duplicate. Pronoun lands in custom_field_1, access
  # needs in custom_field_2, and a do-not-contact prefix on the notes (GDPR consent).
  class Load
    PHASES = %w[categories services providers customers appointments].freeze
    DO_NOT_CONTACT_PREFIX = "[DO NOT CONTACT - consent not granted]".freeze

    def initialize(data, phases:, create_providers: false, progress: nil)
      @data = data
      @phases = Array(phases) & PHASES
      @create_providers = create_providers
      @progress = progress
      @counts = {}
    end

    def call
      load_categories if phase?("categories")
      load_services if phase?("services")
      load_providers if phase?("providers")
      load_customers if phase?("customers")
      load_appointments if phase?("appointments")
      @counts
    end

    private

    def phase?(name) = @phases.include?(name)

    def track(phase)
      @counts[phase.to_sym] = { created: 0, matched: 0, skipped: 0 }
      @progress&.call(phase)
      @counts[phase.to_sym]
    end

    def load_categories
      counts = track("categories")
      names = @data[:services].map { |service| service[:category] }.uniq
      @category_ids = {}
      names.each do |name|
        category = ServiceCategory.find_by(name: name)
        if category
          counts[:matched] += 1
        else
          category = ServiceCategory.create!(name: name)
          counts[:created] += 1
        end
        @category_ids[name] = category.id
      end
    end

    def load_services
      counts = track("services")
      @category_ids ||= ServiceCategory.pluck(:name, :id).to_h
      @service_ids = {}
      @data[:services].each do |row|
        service = Service.find_by(name: row[:name])
        if service
          counts[:matched] += 1
        else
          service = Service.create!(
            name: row[:name], duration: row[:duration] || 30,
            price: row[:price] || 0, currency: row[:currency].presence || "GBP",
            description: row[:description], color: row[:color],
            attendants_number: row[:attendants_number] || 1, is_private: row[:is_private] || false,
            id_service_categories: @category_ids[row[:category]]
          )
          counts[:created] += 1
        end
        @service_ids[row[:name]] = service.id
      end
    end

    def load_providers
      counts = track("providers")
      role = Role.find_by!(slug: Role::PROVIDER)
      @service_ids ||= Service.pluck(:name, :id).to_h
      @provider_ids = {}
      existing = User.providers.to_a.index_by { |user| user.email.to_s.downcase }

      @data[:staff].each do |row|
        provider = existing[row[:email].downcase] if row[:email].present?
        if provider
          counts[:matched] += 1
        elsif @create_providers && row[:email].present?
          provider = User.create!(
            name: row[:name], email: row[:email], phone_number: row[:phone],
            timezone: "Europe/London", role: role
          )
          provider.create_settings!(
            username: row[:username].presence || row[:email].split("@").first,
            password: Passwords.hash(SecureRandom.base58(12)),
            notifications: false,
            working_plan: row[:working_plan].to_json
          )
          counts[:created] += 1
        else
          counts[:skipped] += 1
          next
        end

        service_ids = row[:services].filter_map { |name| @service_ids[name] }
        service_ids.each do |service_id|
          ServiceProviderLink.find_or_create_by!(id_users: provider.id, id_services: service_id)
        end
        @provider_ids[row[:name]] = provider.id
      end
    end

    def load_customers
      counts = track("customers")
      role = Role.find_by!(slug: Role::CUSTOMER)
      @customer_ids = {}
      by_email = {}
      by_name_phone = {}
      User.customers.find_each do |user|
        by_email[user.email.to_s.downcase] = user.id if user.email.present?
        by_name_phone["#{user.name.to_s.downcase}|#{user.phone_number}"] = user.id
      end

      @data[:customers].each do |row|
        existing_id = row[:email].present? ? by_email[row[:email].downcase] : nil
        existing_id ||= by_name_phone["#{row[:name].downcase}|#{row[:phone]}"]
        if existing_id
          counts[:matched] += 1
          @customer_ids[row[:ext_id]] = existing_id
          next
        end

        if row[:name].blank?
          counts[:skipped] += 1
          next
        end

        notes = row[:notes]
        notes = "#{DO_NOT_CONTACT_PREFIX} #{notes}".strip if row[:do_not_contact]
        customer = User.create!(
          name: row[:name], email: row[:email], phone_number: row[:phone],
          address: row[:address], city: row[:city], zip_code: row[:zip], notes: notes,
          custom_field_1: row[:pronoun], custom_field_2: row[:access],
          custom_field_3: row[:custom_field_3], custom_field_4: row[:custom_field_4],
          custom_field_5: row[:custom_field_5], language: row[:language],
          timezone: row[:timezone], role: role
        )
        counts[:created] += 1
        @customer_ids[row[:ext_id]] = customer.id
        by_email[row[:email].downcase] = customer.id if row[:email].present?
        by_name_phone["#{row[:name].downcase}|#{row[:phone]}"] = customer.id
      end
    end

    def load_appointments
      counts = track("appointments")
      provider_ids = @provider_ids || User.providers.to_a.to_h { |user| [ user.name, user.id ] }
      service_ids = @service_ids || Service.pluck(:name, :id).to_h
      customer_ids = @customer_ids || match_existing_customers

      @data[:appointments].each do |row|
        provider_id = provider_ids[row[:staff]]
        service_id = service_ids[row[:service]]
        customer_id = customer_ids[row[:customer_ext_id]]
        if provider_id.nil? || service_id.nil? || customer_id.nil?
          counts[:skipped] += 1
          next
        end

        if Appointment.exists?(id_users_provider: provider_id, id_users_customer: customer_id,
                               start_datetime: row[:start])
          counts[:matched] += 1
          next
        end

        Appointment.create!(
          id_users_provider: provider_id, id_users_customer: customer_id,
          id_services: service_id, start_datetime: row[:start], end_datetime: row[:end],
          notes: row[:note], location: "", book_datetime: Time.now, status: row[:status]
        )
        counts[:created] += 1
      end
    end

    # Ext-id map for an appointments run without the customers phase: match the
    # export's customers against the DB the same way load_customers does.
    def match_existing_customers
      by_email = {}
      by_name_phone = {}
      User.customers.find_each do |user|
        by_email[user.email.to_s.downcase] = user.id if user.email.present?
        by_name_phone["#{user.name.to_s.downcase}|#{user.phone_number}"] = user.id
      end
      @data[:customers].each_with_object({}) do |row, map|
        id = row[:email].present? ? by_email[row[:email].downcase] : nil
        id ||= by_name_phone["#{row[:name].to_s.downcase}|#{row[:phone]}"]
        map[row[:ext_id]] = id if id
      end
    end
  end
end
