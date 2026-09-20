require "test_helper"

class BlockedPeriodsTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def login_customer
    users(:jx).create_settings!(username: "jamesdoe", password: Passwords.hash("customer1"))
    post "/login/validate", params: { username: "jamesdoe", password: "customer1" }
  end

  setup do
    @easter = BlockedPeriod.create!(name: "Easter", start_datetime: "2026-04-03 00:00", end_datetime: "2026-04-07 00:00")
  end

  test "index lists periods newest first with a back link and rows linking to edit" do
    login_admin
    BlockedPeriod.create!(name: "Bank Holiday", start_datetime: "2026-05-04 00:00", end_datetime: "2026-05-05 00:00")
    get "/blocked_periods"
    assert_response :success
    assert_select "turbo-frame#blocked_periods a[href=?]", "/business_settings", text: /Back/
    assert_equal [ "Bank Holiday", "Easter" ], css_select(".blocked-period-row strong").map(&:text)
    assert_select "a[href=?]", "/blocked_periods/#{@easter.id}/edit"
    assert_select ".entry[draggable]", count: 0
  end

  test "new defaults to today until tomorrow with datetime-local fields" do
    login_admin
    get "/blocked_periods/new"
    assert_select "#blocked-periods-page.editing"
    assert_select "turbo-frame#blocked_periods_record form[action='/blocked_periods']" do
      assert_select "input[type=datetime-local][name='blocked_period[start_datetime]'][value=?]",
                    "#{Date.current}T00:00"
      assert_select "input[type=datetime-local][name='blocked_period[end_datetime]'][value=?]",
                    "#{Date.tomorrow}T00:00"
      assert_select "textarea[name='blocked_period[notes]']"
    end
  end

  test "create, update and destroy" do
    login_admin
    post "/blocked_periods", params: {
      blocked_period: { name: "Xmas", start_datetime: "2026-12-24T00:00", end_datetime: "2026-12-28T23:59", notes: "Closed" }
    }
    xmas = BlockedPeriod.find_by!(name: "Xmas")
    assert_redirected_to "/blocked_periods?selected=#{xmas.id}"
    assert_equal "2026-12-28 23:59", xmas.end_datetime.strftime("%F %H:%M")

    patch "/blocked_periods/#{xmas.id}", params: { blocked_period: { name: "Christmas" } }
    assert_redirected_to "/blocked_periods?selected=#{xmas.id}"
    assert_equal "Christmas", xmas.reload.name

    delete "/blocked_periods/#{xmas.id}"
    assert_redirected_to "/blocked_periods"
    assert_not BlockedPeriod.exists?(xmas.id)
  end

  test "an end before the start is rejected with the field marked" do
    login_admin
    patch "/blocked_periods/#{@easter.id}", params: {
      blocked_period: { start_datetime: "2026-04-07T00:00", end_datetime: "2026-04-03T00:00" }
    }
    assert_response :unprocessable_entity
    assert_select "input.is-invalid[name='blocked_period[end_datetime]']"
    assert_select ".form-message[data-tone=error]"
    assert_equal "2026-04-03 00:00", @easter.reload.start_datetime.strftime("%F %H:%M")
  end

  test "the calendar still sees the saved periods" do
    login_admin
    post "/blocked_periods", params: {
      blocked_period: { name: "Xmas", start_datetime: "2026-12-24T00:00", end_datetime: "2026-12-28T00:00" }
    }
    post "/calendar/get_calendar_appointments", params: {
      record_id: users(:zane).id, filter_type: "provider", start_date: "2026-12-20", end_date: "2026-12-31"
    }
    assert_equal [ "Xmas" ], response.parsed_body["blocked_periods"].map { |row| row["name"] }
  end

  test "webhooks fire on save and delete" do
    login_admin
    webhook = Webhook.create!(name: "Hook", url: "https://hooks.example.org/ea",
                              actions: "blocked_period_save,blocked_period_delete")
    patch "/blocked_periods/#{@easter.id}", params: { blocked_period: { notes: "x" } }
    delete "/blocked_periods/#{@easter.id}"
    deliveries = enqueued_jobs.select { |job| job["job_class"] == "WebhookDeliveryJob" }
                              .map { |job| job["arguments"].first(2) }
    assert_equal [ [ webhook.id, Webhooks::BLOCKED_PERIOD_SAVE ], [ webhook.id, Webhooks::BLOCKED_PERIOD_DELETE ] ],
                 deliveries
  end

  test "the old JSON endpoints are gone and customers are forbidden" do
    login_admin
    post "/blocked_periods/store", params: { blocked_period: { name: "x" } }
    assert_response :not_found
    post "/blocked_periods/search", params: { keyword: "" }
    assert_response :not_found

    login_customer
    get "/blocked_periods/new"
    assert_response :forbidden
    delete "/blocked_periods/#{@easter.id}"
    assert_response :forbidden
    assert BlockedPeriod.exists?(@easter.id)
  end
end
