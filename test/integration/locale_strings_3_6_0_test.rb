require "test_helper"

# Every locale carries the 3.6.0 Free page strings.
class LocaleStrings360Test < ActionDispatch::IntegrationTest
  KEYS = %w[free free_hint free_empty].freeze

  test "the 3.6.0 strings exist in every locale" do
    I18n.available_locales.each do |locale|
      KEYS.each do |key|
        value = I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil)
        assert value.present?, "missing ea.#{key} in #{locale}"
      end
    end
    assert_equal "Free", I18n.t("ea.free", locale: :en)
  end
end
