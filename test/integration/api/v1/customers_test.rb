require_relative "api_helper"

module Api
  module V1
    class CustomersTest < ApiTestCase
      test "index returns camelCase customer resources" do
        api_get "/api/v1/customers"
        assert_response :success
        customer = json.find { |c| c["id"] == users(:james).id }
        assert_equal "James Doe", customer["firstName"]
        assert_equal "james@example.org", customer["email"]
        assert_equal "+447700900000", customer["phone"]
        assert customer.key?("zip")
        assert_not customer.key?("phone_number")
      end

      test "keyword search filters by name" do
        api_get "/api/v1/customers", q: "James"
        assert(json.any? { |c| c["firstName"] == "James Doe" })
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
        api_get "/api/v1/customers/#{users(:james).id}"
        assert_equal "James Doe", json["firstName"]
        api_get "/api/v1/customers/999999"
        assert_response :not_found
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
        api_put "/api/v1/customers/#{users(:james).id}", { city: "London" }
        assert_response :success
        assert_equal "London", json["city"]
        assert_equal "London", users(:james).reload.city
      end

      test "destroy removes and 204 then 404" do
        api_delete "/api/v1/customers/#{users(:james).id}"
        assert_response :no_content
        api_delete "/api/v1/customers/#{users(:james).id}"
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
