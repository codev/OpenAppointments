# View helpers mirroring EA's template helper functions (lang, vars, setting).
module EaHelper
  # EA's config('version') (application/config/app.php).
  VERSION = "1.6.0"

  def lang(key)
    t("ea.#{key}", default: key)
  end

  # EA's vars() in views reads the html_vars accumulator.
  def vars(key = nil)
    key ? html_vars[key.to_sym] : html_vars
  end

  def setting(name, default = nil)
    Setting.get(name, default)
  end

  # Script tag for a ported EA JS file under app/javascript (logical path without extension).
  def ea_js(*names)
    safe_join(names.map { |name| javascript_include_tag(name) }, "\n")
  end

  # window.vars / window.lang payloads must be JSON-escaped for inline script tags.
  def inline_json(payload)
    raw ERB::Util.json_escape(payload.to_json) # rubocop:disable Rails/OutputSafety
  end

  # EA Timezones::to_grouped_array equivalent: {continent => {identifier => label}},
  # UTC first, generated from ActiveSupport::TimeZone with IANA identifiers.
  def grouped_timezones
    @grouped_timezones ||= begin
      grouped = { "UTC" => { "UTC" => "UTC" } }
      ActiveSupport::TimeZone.all.sort_by(&:utc_offset).each do |zone|
        identifier = zone.tzinfo.identifier
        next unless identifier.include?("/")

        continent, city = identifier.split("/", 2)
        sign = zone.utc_offset.negative? ? "-" : "+"
        hours, seconds = zone.utc_offset.abs.divmod(3600)
        (grouped[continent] ||= {})[identifier] = "#{city} (#{sign}#{hours}:#{format('%02d', seconds / 60)})"
      end
      grouped
    end
  end
end
