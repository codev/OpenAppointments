require "test_helper"

module Api
  module V1
    class AuthTest < ActionDispatch::IntegrationTest
      setup { Setting.set("api_token", "secret-token") }

      def bearer(token) = { "Authorization" => "Bearer #{token}" }

      def basic(user, pass)
        { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(user, pass) }
      end

      test "valid bearer token is accepted" do
        get "/api/v1/customers", headers: bearer("secret-token")
        assert_response :success
      end

      test "wrong bearer token is rejected with EA contract" do
        get "/api/v1/customers", headers: bearer("nope")
        assert_response :unauthorized
        assert_equal 'Basic realm="OpenAppointments"', response.headers["WWW-Authenticate"]
        assert_equal "You are not authorized to use the API.", response.body
      end

      test "no auth is rejected" do
        get "/api/v1/customers"
        assert_response :unauthorized
      end

      test "basic auth with admin is accepted" do
        get "/api/v1/customers", headers: basic("administrator", "administrator1")
        assert_response :success
      end

      test "basic auth with non-admin is rejected" do
        get "/api/v1/customers", headers: basic("janedoe", "janedoe1")
        assert_response :unauthorized
      end

      test "empty api_token never authorizes a blank bearer" do
        Setting.set("api_token", "")
        get "/api/v1/customers", headers: bearer("")
        assert_response :unauthorized
      end
    end
  end
end
