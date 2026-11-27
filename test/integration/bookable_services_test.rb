require "test_helper"

# A service can be shown on the booking page without being bookable there:
# clients read its description, the wizard never moves on from it, staff
# still book it in the backend.
class BookableServicesTest < ActionDispatch::IntegrationTest
  setup do
    @consult = services(:haircut)
    @consult.update!(is_bookable: false)
  end

  test "services are bookable by default and the form has the switch under Hide From Public" do
    assert Service.new.is_bookable
    assert services(:group_session).is_bookable
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/services/new"
    assert_select "#service_is_private"
    assert_select "#service_is_bookable[checked]"
    assert_select "label[for=service_is_bookable]", text: "Bookable By Public"
    assert_select ".form-text", text: /Untick to show the service/

    patch "/services/#{services(:group_session).id}", params: { service: { is_bookable: "0" } }
    assert_not services(:group_session).reload.is_bookable
  end

  test "the booking page offers the service, marks it not bookable and shows its description" do
    @consult.update!(description: "Ring the salon to arrange a consultation.")
    get "/"
    assert_select "#select-service option[value=?][data-bookable=false]", @consult.id.to_s
    assert_select "#select-service option[value=?]:not([data-bookable])", services(:group_session).id.to_s
    assert_select ".selection-description[data-for-service=?]", @consult.id.to_s, text: /Ring the salon/
  end

  test "the wizard does not move past the service step for a service that is not bookable" do
    get "/", params: { step: "second", service_id: @consult.id }
    assert_select "#wizard-frame-1"
    assert_select "#wizard-frame-2", count: 0
    assert_select "#select-service option[selected][value=?]", @consult.id.to_s

    get "/", params: { step: "time", service_id: @consult.id, provider_id: users(:zane).id }
    assert_select "#wizard-frame-1"
    assert_select "#wizard-frame-3", count: 0

    get "/", params: { step: "second", service_id: services(:group_session).id }
    assert_select "#wizard-frame-2"
  end

  test "provider first still stops at the service step" do
    get "/", params: { first: "provider", step: "time", provider_id: users(:zane).id, service_id: @consult.id }
    assert_select "#wizard-frame-2"
    assert_select "#wizard-frame-3", count: 0
  end

  test "staff still book the service in the backend" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/appointments/new", params: { start: "2026-07-20 11:30:00", provider_id: users(:zane).id }
    assert_select "#select-service option[value=?]", @consult.id.to_s
  end
end
