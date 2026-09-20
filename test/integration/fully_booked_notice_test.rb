require "test_helper"

# Fully Booked Notice: a rich text block on the Notices page, shown on the
# second and time steps when the chosen service or provider has no free hours
# anywhere in the booking window.
class FullyBookedNoticeTest < ActionDispatch::IntegrationTest
  NO_HOURS = { monday: nil, tuesday: nil, wednesday: nil, thursday: nil, friday: nil, saturday: nil, sunday: nil }.to_json

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def fully_book(provider)
    provider.settings.update!(working_plan: NO_HOURS)
  end

  test "the Notices page has the notice below the Booking Notice and saves it sanitised" do
    login_admin
    get "/legal_settings"
    assert_select "#legal-contents h4", text: I18n.t("ea.notices")
    assert_select "#settings-nav span", text: I18n.t("ea.notices")
    assert_select "textarea#fully-booked-notice-content[name='settings[fully_booked_notice_content]']"
    assert_operator response.body.index("booking-notice-content"), :<, response.body.index("fully-booked-notice-content")

    post "/legal_settings/save", params: { settings: { fully_booked_notice_content: "<p>Full up</p><script>x</script>" } }
    assert_equal "<p>Full up</p>x", Setting.get("fully_booked_notice_content")
  end

  test "existing installs get the default text from the migration" do
    Setting.where(name: "fully_booked_notice_content").delete_all
    require Rails.root.glob("db/migrate/*_add_fully_booked_notice_default.rb").first
    ActiveRecord::Migration.suppress_messages { AddFullyBookedNoticeDefault.new.up }
    assert_equal "<p>#{I18n.t('ea.fully_booked_notice_default')}</p>", Setting.get("fully_booked_notice_content")
  end

  test "the notice appears on the provider and time steps only when the service has no free hours" do
    Setting.set("fully_booked_notice_content", "<p>Full up</p>")
    get "/booking", params: { step: "second", service_id: services(:haircut).id }
    assert_select ".fully-booked-notice", 0

    fully_book(users(:zane))
    get "/booking", params: { step: "second", service_id: services(:haircut).id }
    assert_select ".fully-booked-notice", text: "Full up"
    get "/booking", params: { step: "time", service_id: services(:haircut).id, provider_id: users(:zane).id }
    assert_select ".fully-booked-notice", text: "Full up"
    get "/booking", params: { step: "first" }
    assert_select ".fully-booked-notice", 0
  end

  test "with the provider chosen first the notice appears when none of their services has free hours" do
    Setting.set("fully_booked_notice_content", "<p>Full up</p>")
    Setting.set("booking_provider_first", "1")
    get "/booking", params: { step: "second", provider_id: users(:zane).id }
    assert_select ".fully-booked-notice", 0

    fully_book(users(:zane))
    get "/booking", params: { step: "second", provider_id: users(:zane).id }
    assert_select ".fully-booked-notice", text: "Full up"
  end
end
