require_relative "api_helper"

module Api
  module V1
    class CustomersTest < ApiTestCase
      test "index returns camelCase customer resources" do
        api_get "/api/v1/customers"
        assert_response :success
        customer = json.find { |c| c["id"] == users(:jx).id }
        assert_equal "JX", customer["firstName"]
        assert_equal "j@example.org", customer["email"]
        assert_equal "+447700900321", customer["phone"]
        assert customer.key?("zip")
        assert_not customer.key?("phone_number")
      end

      test "keyword search filters by name" do
        api_get "/api/v1/customers", q: "JX"
        assert(json.any? { |c| c["firstName"] == "JX" })
        api_get "/api/v1/customers", q: "zzzznomatch"
        assert_empty json
      end

      test "length and page paginate" do
        api_get "/api/v1/customers", length: 1, page: 1
        assert_equal 1, json.length
      end

      test "sort maps camelCase field and direction" do
        User.customers.create!(name: "Aaron Zed", email: "aaron@example.org",
                               role: Role.find_by(slug: "customer"))
        api_get "/api/v1/customers", sort: "firstName"
        names = json.map { |c| c["firstName"] }
        assert_equal names.sort, names
        api_get "/api/v1/customers", sort: "-firstName"
        names = json.map { |c| c["firstName"] }
        assert_equal names.sort.reverse, names
      end

      test "unknown sort field is silently skipped" do
        api_get "/api/v1/customers", sort: "bogusField"
        assert_response :success
      end

      test "fields projects the response" do
        api_get "/api/v1/customers", fields: "id,firstName"
        assert_equal %w[firstName id], json.first.keys.sort
      end

      test "show returns one or 404" do
        api_get "/api/v1/customers/#{users(:jx).id}"
        assert_equal "JX", json["firstName"]
        api_get "/api/v1/customers/999999"
        assert_response :not_found
      end

      test "name is emitted as an alias for firstName" do
        api_get "/api/v1/customers/#{users(:jx).id}"
        assert_equal "JX", json["name"]
        assert_equal json["firstName"], json["name"]
      end

      test "sort accepts name" do
        User.customers.create!(name: "Aaron Zed", email: "aaron@example.org",
                               role: Role.find_by(slug: "customer"))
        api_get "/api/v1/customers", sort: "name"
        names = json.map { |c| c["name"] }
        assert_equal names.sort, names
      end

      test "store accepts name instead of firstName" do
        assert_difference "User.customers.count", 1 do
          api_post "/api/v1/customers", { name: "Solo Name", email: "solo@example.org" }
        end
        assert_response :created
        assert_equal "Solo Name", json["name"]
        assert_equal "Solo Name", json["firstName"]
      end

      test "name wins over firstName and lastName on write" do
        api_put "/api/v1/customers/#{users(:jx).id}",
                { name: "Alias Wins", firstName: "First", lastName: "Last" }
        assert_response :success
        assert_equal "Alias Wins", users(:jx).reload.name
      end

      test "store creates a customer and returns 201" do
        assert_difference "User.customers.count", 1 do
          api_post "/api/v1/customers", { firstName: "New", lastName: "Person", email: "np@example.org",
                                          phone: "+447700900222" }
        end
        assert_response :created
        assert_equal "New Person", json["firstName"]
        assert User.customers.exists?(email: "np@example.org")
      end

      test "update modifies and returns encoded record" do
        api_put "/api/v1/customers/#{users(:jx).id}", { city: "London" }
        assert_response :success
        assert_equal "London", json["city"]
        assert_equal "London", users(:jx).reload.city
      end

      test "destroy removes and 204 then 404" do
        api_delete "/api/v1/customers/#{users(:jx).id}"
        assert_response :no_content
        api_delete "/api/v1/customers/#{users(:jx).id}"
        assert_response :not_found
      end

      test "writes enqueue customer webhooks" do
        Webhook.create!(name: "hook", url: "https://example.org/h", actions: "customer_save,customer_delete")
        assert_enqueued_with(job: WebhookDeliveryJob) do
          api_post "/api/v1/customers", { firstName: "Hooked", lastName: "User", email: "h@example.org" }
        end
      end
    end
  end
end
