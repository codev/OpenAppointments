require "test_helper"

# Provider About / Description of services provided fields and the booking page
# selection details (picture + description under the dropdowns).
class ProviderDescriptionsTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "provider save round-trips about and services_description" do
    login_admin
    patch "/providers/#{users(:zane).id}", params: {
      provider: { about: "Friendly barber", services_description: "Short cuts and fades" }
    }
    assert_redirected_to "/providers?selected=#{users(:zane).id}"
    zane = users(:zane).reload
    assert_equal "Friendly barber", zane.about
    assert_equal "Short cuts and fades", zane.services_description

    get "/providers/#{zane.id}/edit"
    assert_select "textarea[name='provider[about]']", text: "Friendly barber"
    assert_select "textarea[name='provider[services_description]']", text: "Short cuts and fades"
  end

  test "the providers page offers the two full-width textareas" do
    login_admin
    get "/providers/new"
    assert_select "textarea#provider_about"
    assert_select "textarea#provider_services_description"
    assert_select "label[for=provider_services_description]", text: I18n.t("ea.services_description")
  end

  test "the booking payload carries the provider texts and the page has the details divs" do
    users(:zane).update!(about: "About Zane", services_description: "All the cuts")
    get "/"
    assert_select "#service-description .selection-description[data-for-service]"

    get "/", params: { step: "second", service_id: services(:haircut).id }
    assert_select "#provider-description .selection-description", text: /About Zane/
    assert_select "#provider-description .selection-description", text: /All the cuts/
  end

  test "the services_description label exists in every locale" do
    I18n.available_locales.each do |locale|
      assert I18n.t("ea.services_description", locale: locale, fallback: false, default: nil).present?,
             "missing ea.services_description in #{locale}"
    end
  end
end
