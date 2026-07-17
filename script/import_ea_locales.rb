#!/usr/bin/env ruby
# Regenerate config/locales/*.yml from an Easy!Appointments checkout.
#
#   ruby script/import_ea_locales.rb /path/to/easyappointments
#
# Converts each EA language's translations_lang.php ($lang['key'] = 'value';) into
# a Rails I18n file keyed under the language's ISO-ish code, namespaced ea.*.
require "yaml"
require "fileutils"

EA_ROOT = ARGV[0] or abort("usage: ruby script/import_ea_locales.rb <easyappointments-dir>")
OUT_DIR = File.expand_path("../config/locales", __dir__)

# EA language name => locale code (from EA config.php $languages, inverted).
LANGUAGES = {
  "albanian" => "sq", "arabic" => "ar", "bosnian" => "bs", "bulgarian" => "bu",
  "catalan" => "ca", "chinese" => "zh", "croatian" => "hr", "czech" => "cs",
  "danish" => "da", "dutch" => "nl", "english" => "en", "estonian" => "et",
  "finnish" => "fi", "french" => "fr", "german" => "de", "greek" => "el",
  "hebrew" => "he", "hindi" => "hi", "hungarian" => "hu", "italian" => "it",
  "japanese" => "ja", "latvian" => "lv", "lithuanian" => "lt", "luxembourgish" => "lb",
  "marathi" => "mr", "norwegian" => "no", "persian" => "fa", "polish" => "pl",
  "portuguese" => "pt", "portuguese-br" => "pt-br", "romanian" => "ro", "russian" => "ru",
  "serbian" => "rs", "slovak" => "sk", "slovenian" => "sl", "spanish" => "es",
  "swedish" => "sv", "thai" => "th", "traditional-chinese" => "zh-tw", "turkish" => "tr",
  "ukrainian" => "uk"
}.freeze

LANGUAGES.each do |language, code|
  source = File.join(EA_ROOT, "application/language", language, "translations_lang.php")
  unless File.exist?(source)
    warn "skip #{language}: #{source} not found"
    next
  end

  translations = {}
  File.read(source).scan(/^\$lang\['([^']+)'\]\s*=\s*(['"])(.*)\2;\s*$/) do |key, _quote, value|
    translations[key] = value.gsub("\\'", "'").gsub('\\"', '"')
  end

  File.write(File.join(OUT_DIR, "#{code}.yml"), { code => { "ea" => translations } }.to_yaml(line_width: -1))
  puts "#{code}.yml: #{translations.size} keys"
end
