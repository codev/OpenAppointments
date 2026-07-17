# EA language registry: ISO-ish code => EA language name (directory name upstream,
# locale file name here). Ported from EA's config.php.
module Localization
  LANGUAGES = {
    "sq" => "albanian", "ar" => "arabic", "bs" => "bosnian", "bu" => "bulgarian",
    "ca" => "catalan", "cs" => "czech", "da" => "danish", "de" => "german",
    "el" => "greek", "en" => "english", "es" => "spanish", "et" => "estonian",
    "fa" => "persian", "fi" => "finnish", "fr" => "french", "he" => "hebrew",
    "hi" => "hindi", "hr" => "croatian", "hu" => "hungarian", "it" => "italian",
    "ja" => "japanese", "lb" => "luxembourgish", "lt" => "lithuanian", "lv" => "latvian",
    "mr" => "marathi", "nl" => "dutch", "no" => "norwegian", "pl" => "polish",
    "pt" => "portuguese", "pt-br" => "portuguese-br", "ro" => "romanian", "rs" => "serbian",
    "ru" => "russian", "sk" => "slovak", "sl" => "slovenian", "sv" => "swedish",
    "th" => "thai", "tr" => "turkish", "zh" => "chinese", "zh-tw" => "traditional-chinese",
    "uk" => "ukrainian"
  }.freeze

  module_function

  def available_languages
    LANGUAGES.values.sort
  end

  def code_for(language_name)
    LANGUAGES.key(language_name) || "en"
  end

  def name_for(code)
    LANGUAGES[code] || "english"
  end

  # Flat translation hash for the window.lang payload, from the ea.* locale keys.
  def translations(language_name)
    code = code_for(language_name)
    I18n.t("ea", locale: code, default: {}).transform_keys(&:to_s)
  end
end
