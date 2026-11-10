module TenToEight
  # Finds the configured service a 10to8 service name refers to. The names
  # drift: "S2. Colour 2 hours" for "S2 - Colour 2 hours", double spaces and
  # curly apostrophes, or no code at all ("In person consultation" for
  # "O2 - In person consultation"). Exact name first, then the same name once
  # punctuation is normalised, then a code only one configured service carries,
  # then an uncoded name equal to a configured name with its code removed.
  module ServiceMatch
    CODE = /\A([A-Z]{1,2}\d{1,2})\s*[-–.:]\s*/

    def self.find(name, services)
      name = name.to_s
      normalised = normalise(name)

      services.find { |service| service.name == name } ||
        services.find { |service| normalise(service.name) == normalised } ||
        by_code(name, services) ||
        by_uncoded_name(name, normalised, services)
    end

    def self.by_code(name, services)
      code = code_of(name)
      return if code.nil?

      candidates = services.select { |service| code_of(service.name) == code }
      candidates.one? ? candidates.first : nil
    end

    def self.by_uncoded_name(name, normalised, services)
      return if code_of(name)

      candidates = services.select { |service| code_of(service.name) && normalise(service.name.sub(CODE, "")) == normalised }
      candidates.one? ? candidates.first : nil
    end

    def self.code_of(name)
      name.to_s[CODE, 1]
    end

    def self.normalise(name)
      name.to_s.downcase.tr("’‘", "''").tr("“”", '""').gsub(/[–—]/, "-").gsub(/\s+/, " ").strip
    end
  end
end
