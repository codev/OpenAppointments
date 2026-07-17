require "test_helper"

module Api
  module V1
    # Shared helpers for API v1 request tests: bearer auth + JSON post/put.
    class ApiTestCase < ActionDispatch::IntegrationTest
      TOKEN = "secret-token".freeze

      setup { Setting.set("api_token", TOKEN) }

      def auth = { "Authorization" => "Bearer #{TOKEN}", "Content-Type" => "application/json" }

      def api_get(path, params = {})
        get path, params: params, headers: auth
        response
      end

      def api_post(path, body)
        post path, params: body.to_json, headers: auth
        response
      end

      def api_put(path, body)
        put path, params: body.to_json, headers: auth
        response
      end

      def api_delete(path)
        delete path, headers: auth
        response
      end

      def json = response.parsed_body
    end
  end
end
