require_relative "api_helper"

module Api
  module V1
    # Coverage for the remaining resources: services, categories, providers,
    # secretaries, admins, webhooks, blocked_periods, working_plan_exceptions,
    # unavailabilities, settings, availabilities.
    class ResourcesTest < ApiTestCase
      test "services CRUD with camelCase keys" do
        api_get "/api/v1/services"
        service = json.find { |s| s["id"] == services(:haircut).id }
        assert_equal "Trim Cut", service["name"]
        assert_equal 15, service["slotInterval"]
        assert_equal 1, service["attendantsNumber"]

        api_post "/api/v1/services", { name: "New Service", duration: 45, slotInterval: 15,
                                       serviceCategoryId: service_categories(:hair).id }
        assert_response :created
        assert_equal "New Service", json["name"]
      end

      test "service categories CRUD" do
        api_post "/api/v1/service_categories", { name: "Colour", description: "Colour work" }
        assert_response :created
        id = json["id"]
        api_put "/api/v1/service_categories/#{id}", { description: "Updated" }
        assert_equal "Updated", json["description"]
        api_delete "/api/v1/service_categories/#{id}"
        assert_response :no_content
      end

      test "providers index encodes settings and services" do
        api_get "/api/v1/providers"
        provider = json.find { |p| p["id"] == users(:jane).id }
        assert_equal "Jane Doe", provider["firstName"]
        assert_equal "janedoe", provider["settings"]["username"]
        assert provider["settings"].key?("workingPlan")
        assert provider["settings"].key?("syncFutureDays")
        assert_not provider["settings"].key?("password")
        assert_kind_of Array, provider["services"]
      end

      test "providers with=services embeds raw service rows" do
        api_get "/api/v1/providers", with: "services"
        provider = json.find { |p| p["id"] == users(:jane).id }
        assert_includes provider["services"].map { |s| s["name"] }, "Trim Cut"
        assert provider["services"].first.key?("slot_interval")
      end

      test "services with=category embeds the raw category row" do
        api_get "/api/v1/services/#{services(:haircut).id}", with: "category"
        assert_equal service_categories(:hair).name, json["category"]["name"]
      end

      test "with is silently ignored on resources without relations" do
        api_get "/api/v1/customers", with: "anything"
        assert_response :success
        assert_not json.first.key?("anything")
      end

      test "providers store requires services and settings" do
        api_post "/api/v1/providers", { firstName: "P", lastName: "Q", email: "pq@example.org" }
        assert_response :internal_server_error
        assert_match(/services/, json["message"])

        assert_difference "User.providers.count", 1 do
          api_post "/api/v1/providers", {
            firstName: "New", lastName: "Provider", email: "newprov@example.org",
            services: [ services(:haircut).id ],
            settings: { username: "newprov", password: "provpass1", notifications: true }
          }
        end
        assert_response :created
        created = User.providers.find(json["id"])
        assert_equal [ services(:haircut).id ], created.services.map(&:id)
        assert Passwords.verify(nil, "provpass1", created.settings.password)
        assert created.settings.working_plan.present?
      end

      test "secretaries store persists provider links" do
        assert_difference "User.secretaries.count", 1 do
          api_post "/api/v1/secretaries", {
            firstName: "Sec", lastName: "Retary", email: "sec@example.org",
            providers: [ users(:jane).id ],
            settings: { username: "secretary2", password: "secpass12", notifications: true }
          }
        end
        assert_response :created
        assert_equal [ users(:jane).id ], User.secretaries.find(json["id"]).providers.map(&:id)
      end

      test "admins store persists settings" do
        assert_difference "User.admins.count", 1 do
          api_post "/api/v1/admins", {
            firstName: "Ad", lastName: "Min", email: "ad2@example.org",
            settings: { username: "admin2", password: "adminpass1", notifications: false }
          }
        end
        assert_response :created
        assert_equal "admin2", User.admins.find(json["id"]).settings.username
      end

      test "webhooks CRUD exposes EA keys" do
        api_post "/api/v1/webhooks", { name: "Hook", url: "https://example.org/hook",
                                       actions: "appointment_save", isSslVerified: true, secretToken: "tok" }
        assert_response :created
        assert_equal "Hook", json["name"]
        assert_equal true, json["isSslVerified"]
        assert_equal "appointment_save", json["actions"]
        assert_not json.key?("secretHeader")
      end

      test "blocked periods CRUD" do
        api_post "/api/v1/blocked_periods", { name: "Closed", start: "2026-08-01 00:00:00",
                                              end: "2026-08-02 00:00:00" }
        assert_response :created
        assert_equal "Closed", json["name"]
        assert_equal "2026-08-01 00:00:00", json["start"]
      end

      test "working plan exceptions expose breaks as array" do
        api_post "/api/v1/working_plan_exceptions", {
          startDate: "2026-08-05", endDate: "2026-08-05", startTime: "10:00", endTime: "14:00",
          breaks: [ { "start" => "12:00", "end" => "12:30" } ], providerId: users(:jane).id
        }
        assert_response :created
        assert_equal [ { "start" => "12:00", "end" => "12:30" } ], json["breaks"]
        assert_equal "2026-08-05", json["startDate"]
      end

      test "unavailabilities CRUD scoped and webhook only" do
        Webhook.create!(name: "hook", url: "https://example.org/h", actions: "unavailability_save")
        assert_no_enqueued_emails do
          assert_enqueued_with(job: WebhookDeliveryJob) do
            api_post "/api/v1/unavailabilities", {
              start: "2026-07-22 12:00:00", end: "2026-07-22 13:00:00", providerId: users(:jane).id
            }
          end
        end
        assert_response :created
        assert Appointment.find(json["id"]).is_unavailability
      end

      test "settings collection, by name, and update" do
        api_get "/api/v1/settings"
        assert(json.any? { |s| s["name"] == "company_name" })

        api_get "/api/v1/settings/company_name"
        assert_equal({ "name" => "company_name", "value" => "Test Company" }, json)

        api_get "/api/v1/settings/nonexistent"
        assert_equal({ "name" => "nonexistent", "value" => nil }, json)

        api_put "/api/v1/settings/company_name", { value: "New Co" }
        assert_equal "New Co", json["value"]
        assert_equal "New Co", Setting.get("company_name")
      end

      test "availabilities returns the hour array" do
        travel_to Time.new(2026, 7, 1, 12, 0, 0) do
          api_get "/api/v1/availabilities", providerId: users(:jane).id,
                                            serviceId: services(:haircut).id, date: "2026-07-20"
        end
        assert_response :success
        assert_includes json, "09:00"
        assert_not_includes json, "10:00"
      end
    end
  end
end
