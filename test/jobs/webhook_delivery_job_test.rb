require "test_helper"
require "webmock/minitest"

class WebhookDeliveryJobTest < ActiveJob::TestCase
  setup do
    @webhook = Webhook.create!(name: "Test hook", url: "https://hooks.example.org/ea",
                               actions: "appointment_save,appointment_delete",
                               secret_header: "X-Ea-Token", secret_token: "sekrit")
  end

  test "posts EA body shape with secret header" do
    stub = stub_request(:post, "https://hooks.example.org/ea")
           .with(
             headers: { "Content-Type" => "application/json", "X-Ea-Token" => "sekrit" },
             body: hash_including("action" => "appointment_save",
                                  "payload" => hash_including("id" => appointments(:upcoming).id))
           )
           .to_return(status: 200)

    WebhookDeliveryJob.perform_now(@webhook.id, "appointment_save",
                                   EaRows.appointment_row(appointments(:upcoming)))
    assert_requested stub
  end

  test "no secret header when token blank" do
    @webhook.update!(secret_token: "")
    stub = stub_request(:post, "https://hooks.example.org/ea").to_return(status: 200)

    WebhookDeliveryJob.perform_now(@webhook.id, "appointment_save", { "id" => 1 })
    assert_requested stub
    assert_not_requested(:post, "https://hooks.example.org/ea",
                         headers: { "X-Ea-Token" => "sekrit" })
  end

  test "vanished webhook is a no-op" do
    webhook_id = @webhook.id
    @webhook.destroy!
    WebhookDeliveryJob.perform_now(webhook_id, "appointment_save", {})
    assert_not_requested :post, "https://hooks.example.org/ea"
  end

  test "trigger enqueues only for matching actions" do
    Webhook.create!(name: "Other", url: "https://hooks.example.org/other", actions: "customer_save")

    assert_enqueued_jobs 1, only: WebhookDeliveryJob do
      Webhooks.trigger("appointment_save", appointments(:upcoming))
    end
  end

  test "trigger serializes records to EA rows" do
    assert_enqueued_with(job: WebhookDeliveryJob) do
      Webhooks.trigger("appointment_save", appointments(:upcoming))
    end
    payload = enqueued_jobs.last[:args][2]
    assert_equal "abc123def456", payload["hash"]
    assert_equal "2026-07-20 10:00:00", payload["start_datetime"]
  end
end
