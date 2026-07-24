require "test_helper"

# Provider About / Description of services provided fields and the booking page
# selection details (picture + description under the dropdowns).
class ProviderDescriptionsTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "provider save round-trips about and services_description" do
    login_admin
    post "/providers/update", params: {
      provider: {
        id: users(:zane).id, name: "Zane", email: "zane@example.org",
        about: "Friendly barber", services_description: "Short cuts and fades",
        settings: { username: "janedoe" }
      }
    }
    assert_response :success
    zane = users(:zane).reload
    assert_equal "Friendly barber", zane.about
    assert_equal "Short cuts and fades", zane.services_description

    post "/providers/find", params: { provider_id: zane.id }
    row = response.parsed_body
    assert_equal "Friendly barber", row["about"]
    assert_equal "Short cuts and fades", row["services_description"]
  end

  test "the providers page offers the two full-width textareas" do
    login_admin
    get "/providers"
    assert_select ".col-12 textarea#about"
    assert_select ".col-12 textarea#services-description"
    assert_select "label[for=services-description]", text: I18n.t("ea.services_description")
  end

  test "the booking payload carries the provider texts and the page has the details divs" do
    users(:zane).update!(about: "About Zane", services_description: "All the cuts")
    get "/"
    assert_match(/"about":"About Zane"/, response.body)
    assert_match(/"services_description":"All the cuts"/, response.body)
    assert_select "#provider-description"
    assert_select "#service-description"
  end

  test "the services_description label exists in every locale" do
    I18n.available_locales.each do |locale|
      assert I18n.t("ea.services_description", locale: locale, fallback: false, default: nil).present?,
             "missing ea.services_description in #{locale}"
    end
  end
end
