require "test_helper"

# Busy time types: the CRUD page reached from Business settings, admins only.
class UnavailabilityTypesTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def login_provider
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
  end

  test "business settings has a Busy Time Types section with its hint and a Configure link" do
    login_admin
    get "/business_settings"
    assert_response :success
    assert_select "h5", text: "Busy Time Types"
    assert_select "p", text: /kinds of busy time staff can put on the calendar/
    assert_select "a[href='/unavailability_types']", text: /Configure/
  end

  test "index lists the types in order with a back link; rows link to edit" do
    login_admin
    get "/unavailability_types"
    assert_response :success
    assert_select "turbo-frame#unavailability_types a[href=?]", "/business_settings", text: /Back/
    assert_equal [ "Meeting", "Time off" ], css_select(".unavailability-type-row strong").map(&:text)
    assert_select ".unavailability-type-row .color-swatch[style*='#7cbae8']"
    assert_select "a[href=?]", "/unavailability_types/#{unavailability_types(:meeting).id}/edit"
  end

  test "new shows name and colour; create appends at the end, update and destroy" do
    login_admin
    get "/unavailability_types/new"
    assert_select "#unavailability-types-page.editing"
    assert_select "turbo-frame#unavailability_types_record form[action='/unavailability_types']" do
      assert_select "input[name='unavailability_type[name]'][required]"
      assert_select "input[type=hidden][name='unavailability_type[color]']"
      assert_select ".color-selection-option", minimum: 10
    end

    post "/unavailability_types", params: { unavailability_type: { name: "Travel", color: "#abe9a4" } }
    travel = UnavailabilityType.find_by!(name: "Travel")
    assert_equal [ "Meeting", "Time off", "Travel" ], UnavailabilityType.ordered.pluck(:name)
    assert_redirected_to "/unavailability_types?selected=#{travel.id}"
    follow_redirect!
    assert_select ".alert-success", text: "Type saved."
    assert_equal "#abe9a4", travel.color

    patch "/unavailability_types/#{travel.id}", params: { unavailability_type: { name: "Travelling" } }
    assert_equal "Travelling", travel.reload.name

    appointments(:lunch_block).update!(unavailability_type: travel)
    delete "/unavailability_types/#{travel.id}"
    assert_redirected_to "/unavailability_types"
    follow_redirect!
    assert_select ".alert-success", text: /Type removed/
    assert_not UnavailabilityType.exists?(travel.id)
    assert_nil appointments(:lunch_block).reload.unavailability_type_id
  end

  test "a duplicate name re-renders the form with the error" do
    login_admin
    post "/unavailability_types", params: { unavailability_type: { name: "Meeting", color: "#7cbae8" } }
    assert_response :unprocessable_entity
    assert_select "form .is-invalid[name='unavailability_type[name]']"
  end

  test "a stylist is refused" do
    login_provider
    get "/unavailability_types"
    assert_response :forbidden
    post "/unavailability_types", params: { unavailability_type: { name: "Nope" } }
    assert_response :forbidden
  end
end
