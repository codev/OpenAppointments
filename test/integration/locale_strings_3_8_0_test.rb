require "test_helper"

# Every locale carries the 3.8.0 strings.
class LocaleStrings380Test < ActionDispatch::IntegrationTest
  KEYS = %w[free_from free_to free_reset_hint print_free_title category_services category_no_services
            bookable_by_public bookable_hint
            unavailability_type unavailability_type_none unavailability_types unavailability_types_hint
            unavailability_type_saved unavailability_type_deleted delete_unavailability_type
            unavailability_stylists_hint unavailability_also_for delete_unavailability_group
            activity_unavailability_summary].freeze
  PLACEHOLDERS = { "unavailability_also_for" => %w[{{names}}], "delete_unavailability_group" => %w[{{count}}],
                   "activity_unavailability_summary" => %w[{{type}} {{provider}} {{when}}] }.freeze

  test "the 3.8.0 strings exist in every locale" do
    I18n.available_locales.each do |locale|
      KEYS.each do |key|
        value = I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil)
        assert value.present?, "missing ea.#{key} in #{locale}"
        PLACEHOLDERS.fetch(key, []).each { |token| assert_includes value, token, "ea.#{key} in #{locale} lost #{token}" }
      end
    end
    assert_equal "Bookable By Public", I18n.t("ea.bookable_by_public", locale: :en)
    assert_equal "Busy time", I18n.t("ea.unavailability", locale: :en)
    assert_equal "New Busy Time", I18n.t("ea.new_unavailability_title", locale: :en)
  end
end
