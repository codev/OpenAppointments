require "test_helper"

# Every locale carries the 2.5.0 strings, and the ones this release dropped
# are gone everywhere.
class LocaleStrings250Test < ActiveSupport::TestCase
  KEYS = %w[inbox_filter_archive load_more_messages inbox_info].freeze
  DROPPED = %w[unknown_inbox unknown_inbox_info inbox_show_done inbox_filter_to_do inbox_filter_unread unread].freeze

  test "the 2.5.0 strings exist in every locale and name the Archive button in the help text" do
    I18n.available_locales.each do |locale|
      KEYS.each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?, "missing ea.#{key} in #{locale}"
      end
      archive = I18n.t("ea.inbox_filter_archive", locale: locale)
      assert_includes I18n.t("ea.inbox_info", locale: locale), archive, "#{locale} inbox_info names the Archive button"
    end
  end

  test "the help text was retranslated and the dropped keys are gone" do
    (I18n.available_locales - [ :en ]).each do |locale|
      assert_not_includes I18n.t("ea.inbox_info", locale: locale), "To Do", locale.to_s
    end
    I18n.available_locales.each do |locale|
      DROPPED.each do |key|
        assert_nil I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil), "ea.#{key} still in #{locale}"
      end
    end
  end
end
