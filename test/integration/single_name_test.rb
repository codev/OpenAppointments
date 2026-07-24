require "test_helper"

class SingleNameTest < ActionDispatch::IntegrationTest
  TOKEN = "secret-token".freeze

  setup { Setting.set("api_token", TOKEN) }

  def auth = { "Authorization" => "Bearer #{TOKEN}", "Content-Type" => "application/json" }

  test "users have a single required name" do
    user = User.new(email: "n@example.org", role: Role.find_by(slug: "customer"))
    assert_not user.valid?
    user.name = "Ada Lovelace Byron"
    assert user.valid?
    assert_equal "Ada Lovelace Byron", user.full_name
  end

  test "API accepts EA firstName and lastName and joins them" do
    post "/api/v1/customers", headers: auth,
         params: { firstName: "Ada", lastName: "Lovelace", email: "ada@example.org" }.to_json
    assert_response :created
    assert_equal "Ada Lovelace", User.find(response.parsed_body["id"]).name
  end

  test "API accepts firstName alone" do
    post "/api/v1/customers", headers: auth,
         params: { firstName: "Cher", email: "cher@example.org" }.to_json
    assert_response :created
    assert_equal "Cher", User.find(response.parsed_body["id"]).name
  end

  test "API emits the compat shim shape" do
    get "/api/v1/customers/#{users(:jx).id}", headers: auth
    assert_equal users(:jx).name, response.parsed_body["firstName"]
    assert_equal "", response.parsed_body["lastName"]
  end

  test "API keyword search matches the name column" do
    get "/api/v1/customers", headers: auth, params: { q: users(:jx).name.split.first }
    assert(response.parsed_body.any? { |c| c["id"] == users(:jx).id })
  end

  test "booking register accepts a single name field" do
    params = {
      post_data: {
        appointment: {
          "start_datetime" => "2026-07-20 11:00:00",
          "id_services" => services(:haircut).id, "id_users_provider" => users(:zane).id
        },
        customer: { "name" => "Solo Booker", "email" => "solo@example.org",
                    "phone_number" => "+447700900333" },
        manage_mode: false
      }
    }
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      assert_difference "User.customers.count", 1 do
        post "/booking/register", params: params
      end
    end
    assert_response :success
    assert User.customers.exists?(name: "Solo Booker")
  end

  test "EaRows user rows carry name only" do
    row = EaRows.user_row(users(:jx))
    assert_equal users(:jx).name, row["name"]
    assert_not row.key?("first_name")
    assert_not row.key?("last_name")
  end
end
