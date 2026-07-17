require_relative "api_helper"

module Api
  module V1
    class AppointmentsTest < ApiTestCase
      test "index encodes EA appointment keys with naive datetimes" do
        api_get "/api/v1/appointments"
        appointment = json.find { |a| a["id"] == appointments(:upcoming).id }
        assert_equal "2026-07-20 10:00:00", appointment["start"]
        assert_equal "2026-07-20 10:30:00", appointment["end"]
        assert_equal "abc123def456", appointment["hash"]
        assert_equal users(:jane).id, appointment["providerId"]
        assert_equal services(:haircut).id, appointment["serviceId"]
        assert_not appointment.key?("start_datetime")
      end

      test "index excludes unavailabilities" do
        api_get "/api/v1/appointments"
        assert_not(json.any? { |a| a["id"] == appointments(:lunch_block).id })
      end

      test "date and provider filters" do
        api_get "/api/v1/appointments", date: "2026-07-20", providerId: users(:jane).id
        assert_equal 1, json.length
        api_get "/api/v1/appointments", date: "2026-07-19"
        assert_empty json
        api_get "/api/v1/appointments", from: "2026-07-20", till: "2026-07-21"
        assert_equal 1, json.length
      end

      test "with embeds raw service, provider and customer rows after fields projection" do
        api_get "/api/v1/appointments/#{appointments(:upcoming).id}", fields: "id", with: "customer,service"
        assert_equal "James Doe", json["customer"]["name"]
        assert_equal "Trim Cut", json["service"]["name"]
        assert_not json.key?("provider")
        assert_not json.key?("start")

        api_get "/api/v1/appointments", with: "provider"
        appointment = json.find { |a| a["id"] == appointments(:upcoming).id }
        assert_equal "Jane Doe", appointment["provider"]["name"]
      end

      test "unknown with relation returns the EA json error" do
        api_get "/api/v1/appointments", with: "bogus"
        assert_response :internal_server_error
        assert_equal false, json["success"]
      end

      test "keyword search replaces the where filters (EA quirk)" do
        api_get "/api/v1/appointments", q: "abc123", date: "1999-01-01"
        assert(json.any? { |a| a["id"] == appointments(:upcoming).id })
      end

      test "store creates appointment, computes end from service duration, fires side effects" do
        Webhook.create!(name: "hook", url: "https://example.org/h", actions: "appointment_save")
        assert_enqueued_emails 3 do
          assert_enqueued_with(job: WebhookDeliveryJob) do
            api_post "/api/v1/appointments", {
              start: "2026-07-21 09:00:00", serviceId: services(:haircut).id,
              providerId: users(:jane).id, customerId: users(:james).id
            }
          end
        end
        assert_response :created
        assert_equal "2026-07-21 09:30:00", json["end"]
        appointment = Appointment.find(json["id"])
        assert_not appointment.is_unavailability
      end

      test "update merges and notifies" do
        assert_enqueued_emails 3 do
          api_put "/api/v1/appointments/#{appointments(:upcoming).id}", { notes: "Updated via API" }
        end
        assert_response :success
        assert_equal "Updated via API", appointments(:upcoming).reload.notes
      end

      test "invalid references return a JSON error, not an HTML 500" do
        api_post "/api/v1/appointments", {
          start: "2026-07-21 09:00:00", serviceId: services(:haircut).id,
          providerId: users(:jane).id, customerId: 999_999
        }
        assert_response :internal_server_error
        assert_equal false, json["success"]
        assert json["message"].present?
      end

      test "destroy removes and notifies" do
        assert_difference "Appointment.appointments.count", -1 do
          api_delete "/api/v1/appointments/#{appointments(:upcoming).id}"
        end
        assert_response :no_content
      end
    end
  end
end
