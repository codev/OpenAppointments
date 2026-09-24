require "csv"

module TenToEight
  # Port of import/extract.py: parses a raw 10to8 export CSV into clean
  # services / staff / customers / appointments structures.
  class Extract
    NON_SERVICE = [ "Blocked Time", "Buffer time", "Travel Time", "On leave", "Break",
                    "Unwell", "Q - staff meeting", "Qa - admin tasks", "access notes" ].freeze

    CATEGORY_PREFIXES = {
      "TC" => "Clipper trims", "TS" => "Scissor trims",
      "RS" => "Restyles (scissor)", "RC" => "Restyles (clipper)",
      "C" => "Curly hair", "F" => "Facial hair", "S" => "Colour"
    }.freeze

    ACCESS_COL = "Do you have access needs you would like us to be aware of? " \
                 "(optional) e.g disabilities, sensory needs, larger chair".freeze
    PRONOUN_COL = "What pronoun would you like us to use? (optional)".freeze

    DAYS = %w[monday tuesday wednesday thursday friday saturday sunday].freeze

    def initialize(path, today: Date.current, days_back: 21, days_forward: 21)
      @path = path
      @today = today
      @days_back = days_back.to_i.clamp(0, 3650)
      @days_forward = days_forward.to_i.clamp(0, 3650)
      @svc_recent_from = (today << 6).to_time
      @wp_from = (today << 9).to_time
    end

    def call
      events = {}
      customers = {}
      staff_contact = Hash.new { |hash, key| hash[key] = { emails: [], phones: [] } }
      svc_seen = {}
      prov_svc = Hash.new { |hash, key| hash[key] = [] }
      wp_samples = Hash.new { |hash, key| hash[key] = Hash.new { |h, k| h[k] = { starts: [], ends: [] } } }

      CSV.foreach(@path, headers: true, encoding: "bom|utf-8") do |row|
        staff_name = row["Staff Name"].to_s.strip
        service_name = row["Appointment Name"].to_s.strip
        event_id = row["Event ID"].to_s.strip
        start_at = parse_dt(row["Start Date"])
        length = row["Length"].to_s.to_i

        if staff_name.present?
          row["Staffs Emails"].to_s.split(";").each do |email|
            staff_contact[staff_name][:emails] << email.strip if email.include?("@")
          end
          row["Staffs phone numbers"].to_s.split(";").each do |phone|
            staff_contact[staff_name][:phones] << phone.strip if phone.strip.present?
          end
        end

        if service_name.present? && NON_SERVICE.exclude?(service_name) && start_at
          record = svc_seen[service_name] ||= { lengths: Hash.new(0), last: start_at }
          record[:lengths][length] += 1
          record[:last] = start_at if start_at > record[:last]
          prov_svc[staff_name] |= [ service_name ] if start_at >= @svc_recent_from && staff_name.present?

          if start_at >= @wp_from && staff_name.present?
            sample = wp_samples[staff_name][start_at.wday]
            end_at = start_at + length * 60
            sample[:starts] << start_at.hour + start_at.min / 60.0
            sample[:ends] << end_at.hour + end_at.min / 60.0
          end
        end

        customer_id = row["Customer ID"].to_s.strip
        if customer_id.present?
          customer = customers[customer_id] ||= {}
          best(customer, :name, row["Customer Name"])
          best(customer, :email, row["Customer Emails"].to_s.split(";").first)
          best(customer, :phone_raw, row["Customer Phone Numbers"].to_s.split(";").first)
          best(customer, :pronoun, row[PRONOUN_COL])
          best(customer, :access, row[ACCESS_COL])
          best(customer, :address, row["Customer Home Addresses"].to_s.split(";").first)
          best(customer, :tags, row["Customer Tags"])
          consent = row["Customer Consent"].to_s
          if consent.include?("not grante")
            customer[:consent] = "no"
          elsif consent.include?("granted") && customer[:consent] != "no"
            customer[:consent] = "yes"
          end
        end

        if event_id.present? && start_at && !events.key?(event_id)
          events[event_id] = {
            event_id: event_id, start: start_at, end: start_at + length * 60,
            service: service_name, staff: staff_name, customer_ext_id: customer_id,
            status: row["Status"].to_s.strip, note: row["Appointment Note Text"].to_s.strip
          }
        end
      end

      {
        services: services_output(svc_seen),
        staff: staff_output(staff_contact, prov_svc, wp_samples),
        customers: customers_output(customers),
        appointments: appointments_output(events)
      }
    end

    private

    def best(hash, key, value)
      value = value.to_s.strip
      hash[key] = value if value.present? && hash[key].blank?
    end

    # "Jul 15 2026 10:00 AM" (extract.py "%b %d %Y %I:%M %p"); wall-clock Time.
    def parse_dt(value)
      value = value.to_s.strip
      return nil if value.blank?

      Time.strptime(value, "%b %d %Y %I:%M %p")
    rescue ArgumentError
      nil
    end

    def category_for(name)
      prefix = name[/\A\s*([A-Za-z]+)/, 1].to_s.upcase
      CATEGORY_PREFIXES.fetch(prefix, "Other")
    end

    def services_output(svc_seen)
      svc_seen.select { |_name, record| record[:last] >= @svc_recent_from }
              .sort_by { |_name, record| -record[:lengths].values.sum }
              .map do |name, record|
        duration = record[:lengths].max_by { |_len, count| count }&.first
        { name: name, duration: duration, category: category_for(name),
          last_used: record[:last].to_date, times_booked: record[:lengths].values.sum }
      end
    end

    def staff_output(staff_contact, prov_svc, wp_samples)
      staff_contact.keys.sort.map do |name|
        phone, = e164(staff_contact[name][:phones].sort.first)
        plan = {}
        DAYS.each_with_index do |day, index|
          wday = (index + 1) % 7 # DAYS starts monday; Time#wday starts sunday
          sample = wp_samples[name][wday]
          plan[day] =
            if sample[:starts].size >= 5
              { "start" => hhmm(floor_q(pct(sample[:starts], 10))),
                "end" => hhmm(ceil_q(pct(sample[:ends], 90))), "breaks" => [] }
            end
        end
        { name: name, email: staff_contact[name][:emails].sort.first.to_s, phone: phone,
          services: prov_svc[name].sort, working_plan: plan }
      end
    end

    def customers_output(customers)
      customers.map do |ext_id, customer|
        phone, = e164(customer[:phone_raw])
        notes = customer[:tags].present? ? "Tags: #{customer[:tags]}" : ""
        { ext_id: ext_id, name: customer[:name].to_s, email: customer[:email].to_s,
          phone: phone, pronoun: customer[:pronoun].to_s, access: customer[:access].to_s,
          address: customer[:address].to_s, do_not_contact: customer[:consent] == "no",
          notes: notes }
      end
    end

    def appointments_output(events)
      lo = @today - @days_back
      hi = @today + @days_forward
      events.values.sort_by { |event| event[:start] }.select do |event|
        event[:start].to_date.between?(lo, hi) &&
          NON_SERVICE.exclude?(event[:service]) &&
          %w[Booked Rebooked].include?(event[:status])
      end
    end

    # Best-effort UK E.164 (extract.py e164()).
    def e164(raw)
      raw = raw.to_s.strip
      return [ "", "empty" ] if raw.blank?

      raw = raw.split(%r{[;,/]}).first.to_s.strip
      plus = raw.start_with?("+")
      digits = raw.gsub(/\D/, "")
      return [ "", "no-digits" ] if digits.blank?
      return [ "+#{digits}", "" ] if plus || digits.start_with?("44")
      return [ "+44#{digits[1..]}", "" ] if digits.start_with?("0")
      return [ "+44#{digits}", "" ] if digits.start_with?("7") && digits.length == 10
      return [ "+#{digits}", "unverified-prefix" ] if digits.length >= 10

      [ "", "too-short" ]
    end

    def pct(values, percentile)
      return nil if values.empty?

      sorted = values.sort
      index = ((percentile / 100.0) * (sorted.length - 1)).round.clamp(0, sorted.length - 1)
      sorted[index]
    end

    def floor_q(hours) = hours.to_i + ((hours - hours.to_i) >= 0.5 ? 0.5 : 0.0)

    def ceil_q(hours)
      base = hours.to_i
      fraction = hours - base
      base + (fraction.zero? ? 0.0 : (fraction <= 0.5 ? 0.5 : 1.0))
    end

    def hhmm(hours) = format("%02d:%02d", hours.to_i, ((hours % 1) * 60).round)
  end
end
