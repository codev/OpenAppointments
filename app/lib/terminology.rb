# Admin-configurable names for "provider" and "service" in the English interface.
# Rewrites ea.* strings at the lang()/window.lang choke points; other locales are
# left untouched. Blank settings mean no rewrite.
module Terminology
  SETTINGS = %w[provider_label provider_label_plural service_label service_label_plural].freeze

  # Keys where "provider"/"service" mean something else (captcha, SMS and email
  # providers) plus the terminology settings form itself.
  SKIP_PREFIXES = %w[captcha_ messages_ notification_ about_app_ terminology provider_label service_label].freeze

  WORDS = {
    "providers" => "provider_label_plural",
    "provider" => "provider_label",
    "services" => "service_label_plural",
    "service" => "service_label"
  }.freeze

  module_function

  def labels
    Setting.get_many(SETTINGS).transform_values { |v| v.to_s.strip.presence }
  end

  def active?(locale = I18n.locale, current = labels)
    locale.to_s == "en" && current.values.any?
  end

  def apply(key, text, current = labels, locale = I18n.locale)
    return text unless text.is_a?(String) && active?(locale, current)
    return text if SKIP_PREFIXES.any? { |prefix| key.to_s.start_with?(prefix) }

    WORDS.reduce(text) { |acc, (word, setting)| substitute(acc, word, current[setting]) }
  end

  def apply_all(translations, locale = I18n.locale)
    current = labels
    return translations unless active?(locale, current)

    translations.to_h { |key, text| [ key, apply(key, text, current, locale) ] }
  end

  # Case-preserving whole-word replace: "Provider" -> "Stylist", "provider" -> "stylist".
  def substitute(text, word, label)
    return text if label.blank?

    text.gsub(/\b#{word}\b/i) { |match| match[0] == match[0].upcase ? label : label[0].downcase + label[1..] }
  end
end
