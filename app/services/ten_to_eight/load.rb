module TenToEight
  # Port of import/load_to_ea.py, writing straight to the models. Matches existing
  # records (categories/services by name, providers by email, customers by email or
  # name+phone) so re-runs do not duplicate. Pronoun lands in custom_field_1, access
  # needs in custom_field_2, and a do-not-contact prefix on the notes (GDPR consent).
  class Load
    PHASES = %w[categories services providers assistants admins customers appointments settings].freeze
    DO_NOT_CONTACT_PREFIX = "[DO NOT CONTACT - consent not granted]".freeze

    def initialize(data, phases:, create_providers: false, progress: nil, images_dir: nil)
      @data = data
      @phases = Array(phases) & PHASES
      @create_providers = create_providers
      @progress = progress
      @images_dir = images_dir
      @counts = {}
      @errors = []
    end

    def call
      load_categories if phase?("categories")
      load_services if phase?("services")
      load_providers if phase?("providers")
      load_assistants if phase?("assistants")
      load_admins if phase?("admins")
      load_customers if phase?("customers")
      load_appointments if phase?("appointments")
      load_settings if phase?("settings")
      { counts: @counts, errors: @errors }
    end

    private

    def phase?(name) = @phases.include?(name)

    # Restores every exported setting by internal key; new settings flow through
    # automatically because the export dumps the whole settings table.
    def load_settings
      counts = track("settings")
      Array(@data[:settings]).each do |row|
        guard("settings", counts, row[:name]) do
          next counts[:skipped] += 1 if row[:name].blank?

          existing = Setting.find_by(name: row[:name])
          Setting.set(row[:name], row[:value].to_s)
          counts[existing ? :matched : :created] += 1
        end
      end
    end

    def track(phase)
      @counts[phase.to_sym] = { created: 0, matched: 0, skipped: 0, failed: 0 }
      @progress&.call(phase)
      @counts[phase.to_sym]
    end

    # A bad record must not abort the run: count it, remember what failed and
    # carry on. Returns the block value, or nil on failure.
    def guard(phase, counts, item)
      yield
    rescue ActiveRecord::ActiveRecordError => e
      counts[:failed] += 1
      @errors << { phase: phase, item: item, message: e.message }
      nil
    end

    # Attach a picture referenced by filename from the import bundle's images
    # directory. Existing pictures are kept.
    def attach_picture(record, filename)
      return if @images_dir.blank? || filename.blank? || record.picture.attached?

      path = File.join(@images_dir, File.basename(filename.to_s))
      return unless File.exist?(path)

      record.picture.attach(io: File.open(path), filename: File.basename(path))
    end

    def load_categories
      counts = track("categories")
      extras = Array(@data[:categories])
      extra_by_name = extras.index_by { |row| row[:name] }
      names = (@data[:services].map { |service| service[:category] } +
               extras.map { |row| row[:name] }).compact.uniq
      @category_ids = {}
      names.each do |name|
        extra = extra_by_name[name] || {}
        category = ServiceCategory.find_by(name: name)
        if category
          counts[:matched] += 1
          if category.description.blank? && extra[:description].present?
            category.update(description: extra[:description])
          end
        else
          category = guard("categories", counts, name) do
            ServiceCategory.create!(name: name, description: extra[:description])
          end
          next unless category

          counts[:created] += 1
        end
        attach_picture(category, extra[:picture])
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
          if service.description.blank? && row[:description].present?
            service.update(description: row[:description])
          end
        else
          service = guard("services", counts, row[:name]) do
            Service.create!(
              name: row[:name], duration: [ (row[:duration] || 30).to_i, 5 ].max,
              price: row[:price] || 0, currency: row[:currency].presence || "GBP",
              description: row[:description], color: row[:color],
              attendants_number: row[:attendants_number] || 1, is_private: row[:is_private] || false,
              id_service_categories: @category_ids[row[:category]]
            )
          end
          next unless service

          counts[:created] += 1
        end
        attach_picture(service, row[:picture])
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
          updates = {}
          updates[:about] = row[:about] if provider.about.blank? && row[:about].present?
          if provider.services_description.blank? && row[:services_description].present?
            updates[:services_description] = row[:services_description]
          end
          provider.update(updates) if updates.any?
          restore_password(provider, row[:password_hash])
        elsif @create_providers && row[:email].present?
          provider = guard("providers", counts, row[:name].presence || row[:email]) do
            user = User.create!(
              name: row[:name], email: row[:email], phone_number: row[:phone],
              about: row[:about], services_description: row[:services_description],
              timezone: "Europe/London", role: role
            )
            user.create_settings!(
              username: row[:username].presence || row[:email].split("@").first,
              password: row[:password_hash].presence || Passwords.hash(SecureRandom.base58(12)),
              notifications: false,
              working_plan: row[:working_plan].to_json
            )
            user
          end
          next unless provider

          counts[:created] += 1
        else
          counts[:skipped] += 1
          next
        end

        guard("providers", counts, row[:name].presence || row[:email]) do
          row[:services].filter_map { |name| @service_ids[name] }.each do |service_id|
            ServiceProviderLink.find_or_create_by!(id_users: provider.id, id_services: service_id)
          end
        end
        attach_picture(provider, row[:picture])
        @provider_ids[row[:name]] = provider.id
      end
    end

    # Hashes round-trip as stored, so restored logins keep their passwords.
    def restore_password(user, password_hash)
      user.settings.update(password: password_hash) if password_hash.present? && user.settings
    end

    # Only OpenAppointments ODS backups carry assistants and admins (10to8
    # exports have no such sheets).
    def load_assistants
      return if Array(@data[:assistants]).empty?

      counts = track("assistants")
      role = Role.find_by!(slug: Role::ASSISTANT)
      provider_ids = User.providers.pluck(:name, :id).to_h
      upsert_staff(@data[:assistants], counts, "assistants", User.assistants, role) do |assistant, row|
        Array(row[:providers]).filter_map { |name| provider_ids[name] }.each do |provider_id|
          AssistantProviderLink.create!(id_users_assistant: assistant.id, id_users_provider: provider_id)
        end
      end
    end

    def load_admins
      return if Array(@data[:admins]).empty?

      counts = track("admins")
      role = Role.find_by!(slug: Role::ADMIN)
      upsert_staff(@data[:admins], counts, "admins", User.admins, role)
    end

    def upsert_staff(rows, counts, phase, scope, role)
      existing = scope.to_a.index_by { |user| user.email.to_s.downcase }
      rows.each do |row|
        user = existing[row[:email].to_s.downcase] if row[:email].present?
        if user
          counts[:matched] += 1
          restore_password(user, row[:password_hash])
        elsif @create_providers && row[:email].present?
          user = guard(phase, counts, row[:name].presence || row[:email]) do
            created = User.create!(
              name: row[:name], email: row[:email], phone_number: row[:phone],
              timezone: row[:timezone].presence || "Europe/London", role: role
            )
            created.create_settings!(
              username: row[:username].presence || row[:email].split("@").first,
              password: row[:password_hash].presence || Passwords.hash(SecureRandom.base58(12)),
              notifications: false
            )
            yield(created, row) if block_given?
            created
          end
          next unless user

          counts[:created] += 1
        else
          counts[:skipped] += 1
        end
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
        customer = guard("customers", counts, row[:name]) do
          User.create!(
            name: row[:name], email: row[:email], phone_number: row[:phone],
            address: row[:address], city: row[:city], zip_code: row[:zip], notes: notes,
            custom_field_1: row[:pronoun], custom_field_2: row[:access],
            custom_field_3: row[:custom_field_3], custom_field_4: row[:custom_field_4],
            custom_field_5: row[:custom_field_5], language: row[:language],
            timezone: row[:timezone], role: role
          )
        end
        next unless customer

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

        appointment = guard("appointments", counts, "#{row[:staff]} / #{row[:customer_ext_id]} @ #{row[:start]}") do
          Appointment.create!(
            id_users_provider: provider_id, id_users_customer: customer_id,
            id_services: service_id, start_datetime: row[:start], end_datetime: row[:end],
            notes: row[:note], location: "", book_datetime: Time.now, status: row[:status]
          )
        end
        next unless appointment

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
