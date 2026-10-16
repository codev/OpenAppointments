require "test_helper"

# The Booking Settings page leads with the Options, switches in a fixed order.
class BookingSettingsOrderTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  ORDER = %w[
    disable_booking booking_display_mode picture_style_categories display_any_provider
    booking_provider_first display_order_switch appointments_include_locations
    appointments_include_meeting_links limit_customer_access display_login_button
    display_delete_personal_information display_powered_by display_email
  ].freeze

  test "options come before the fields in the documented order" do
    login_admin
    get "/booking_settings"
    names = css_select("[name^='settings[']").map { |el| el["name"][/\[(.*)\]/, 1] }.uniq
    positions = ORDER.map { |key| names.index(key) }
    assert_not_includes positions, nil
    assert_equal positions.sort, positions
  end

  test "the staff login, stylist first and switch hints are shown" do
    login_admin
    get "/booking_settings"
    assert_select "small", text: I18n.t("ea.display_login_button_hint")
    assert_select "small", text: I18n.t("ea.booking_provider_first_hint")
    assert_select "small", text: I18n.t("ea.display_order_switch_hint")
  end
end
