require "test_helper"

# Every locale carries the 3.2.0 strings: the About & Services tab and the
# notes hint on the stylist page; the dialog's end date and time label is gone.
class LocaleStrings320Test < ActionDispatch::IntegrationTest
  KEYS = %w[about_and_services notes_internal_hint].freeze
  DROPPED = %w[end_date_time].freeze

  test "the 3.2.0 strings exist in every locale and the dropped keys are gone" do
    I18n.available_locales.each do |locale|
      KEYS.each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?, "missing ea.#{key} in #{locale}"
      end
      DROPPED.each do |key|
        assert_nil I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil), "ea.#{key} still in #{locale}"
      end
    end
    assert_equal "About & Services", I18n.t("ea.about_and_services", locale: :en)
    assert_equal "Internal notes - visible to people with a staff login", I18n.t("ea.notes_internal_hint", locale: :en)
  end

  test "the stylist page shows the tab and the notes hint" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/providers/#{users(:zane).id}/edit"
    assert_select "a[href='#about-services']", text: I18n.t("ea.about_and_services")
    assert_select ".form-text", text: I18n.t("ea.notes_internal_hint")
  end
end
