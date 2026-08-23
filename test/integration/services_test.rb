require "test_helper"

class ServicesTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def png = fixture_file_upload("picture.png", "image/png")

  test "index rows show duration and price and are draggable; new has EA's defaults" do
    login_admin
    get "/services"
    assert_select ".service-row[draggable=true][data-id=?] small", services(:haircut).id.to_s, text: "30 min - 0.0 GBP"
    assert_select ".sort-alphabetically"

    get "/services/new"
    assert_select "turbo-frame#services_record form[action='/services'][enctype='multipart/form-data']" do
      assert_select "input[name='service[name]'][value=Service]"
      assert_select "input[name='service[duration]'][value='30'][min=?]", Appointment::EVENT_MINIMUM_DURATION.to_s
      assert_select "input[name='service[slot_interval]'][value='15']"
      assert_select "input[name='service[attendants_number]'][value='1']"
      assert_select "select[name='service[id_service_categories]'] option[value=?]", service_categories(:hair).id.to_s
      assert_select "input[type=hidden][name='service[color]'][value='#7cbae8']"
      assert_select "input[type=checkbox][name='service[providers][]'][value=?]", users(:zane).id.to_s
      assert_select "a[href*='regenerate_link']", count: 0
    end
  end

  test "edit shows the booking links and linked providers" do
    login_admin
    haircut = services(:haircut)
    haircut.update!(color: "#eb8687")
    get "/services/#{haircut.id}/edit"
    assert_select "a[href=?][target=_blank]", "/?service=#{haircut.booking_slug}"
    assert_select "a[href=?]", "/?provider=#{users(:zane).booking_slug}&service=#{haircut.booking_slug}"
    assert_select "form[action=?] button[data-turbo-confirm-button=?]", "/services/#{haircut.id}/regenerate_link",
                  I18n.t("ea.change")
    assert_select "input[name='service[providers][]'][value=?][checked]", users(:zane).id.to_s
    assert_select ".color-selection-option.selected[data-value='#eb8687']"
    assert_select "input[type=hidden][name='service[color]'][value='#eb8687']"
  end

  test "create with picture and providers, update clears providers, destroy removes appointments" do
    login_admin
    post "/services", params: {
      service: { name: "Colour", duration: 45, price: "40", currency: "GBP", slot_interval: 15, attendants_number: 1,
                 id_service_categories: service_categories(:hair).id, color: "#eb8687", is_private: "1",
                 picture: png, providers: [ "", users(:zane).id ] }
    }
    colour = Service.find_by!(name: "Colour")
    assert_redirected_to "/services?selected=#{colour.id}"
    assert colour.picture.attached? && colour.picture_padded.attached?
    assert_equal [ users(:zane).id ], colour.provider_links.map(&:id_users)
    assert colour.is_private
    assert_equal service_categories(:hair), colour.category

    patch "/services/#{colour.id}", params: { service: { providers: [ "" ], remove_picture: "1" } }
    assert_equal [], colour.reload.provider_links.map(&:id_users)
    assert_not colour.picture.attached?

    patch "/services/#{colour.id}", params: { service: { name: "Colour 2" } }
    assert_equal "Colour 2", colour.reload.name

    Appointment.create!(id_users_provider: users(:zane).id, id_users_customer: users(:jx).id, id_services: colour.id,
                        start_datetime: "2026-09-01 10:00", end_datetime: "2026-09-01 10:45")
    assert_difference "Appointment.count", -1 do
      delete "/services/#{colour.id}"
    end
    assert_redirected_to "/services"
  end

  test "regenerate link changes the slug and returns the edit form" do
    login_admin
    haircut = services(:haircut)
    post "/services/#{haircut.id}/regenerate_link"
    assert_redirected_to "/services/#{haircut.id}/edit"
    assert_not_equal "abcd-efgh", haircut.reload.booking_slug
    follow_redirect!
    assert_select "a[href=?]", "/?service=#{haircut.booking_slug}"
  end

  test "a duration under the minimum and a blank name are refused" do
    login_admin
    post "/services", params: { service: { name: "", duration: 1 } }
    assert_response :unprocessable_entity
    assert_select "input.is-invalid[name='service[name]']"
    assert_select "input.is-invalid[name='service[duration]']"
  end

  test "the old JSON endpoints are gone and customers are forbidden" do
    login_admin
    post "/services/search", params: { keyword: "" }
    assert_response :not_found
    post "/services/regenerate_link", params: { service_id: services(:haircut).id }
    assert_response :not_found
    post "/services/#{services(:haircut).id}/picture", params: { picture: png }
    assert_response :not_found

    users(:jx).create_settings!(username: "jamesdoe", password: Passwords.hash("customer1"))
    post "/login/validate", params: { username: "jamesdoe", password: "customer1" }
    post "/services/#{services(:haircut).id}/regenerate_link"
    assert_response :forbidden
    delete "/services/#{services(:haircut).id}"
    assert_response :forbidden
  end
end
