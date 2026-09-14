require "test_helper"

# Every settings page shows the stored value of every text field it posts.
# A field rendered without its value (or without a name) is how the
# terminology labels went missing after the pages became Rails forms.
class SettingsRoundTripTest < ActionDispatch::IntegrationTest
  PAGES = %w[general_settings business_settings booking_settings legal_settings api_settings
             google_analytics_settings matomo_analytics_settings umami_analytics_settings
             jitsi_settings ldap_settings embed_settings altcha_settings messages_settings
             messages_email_settings messages_twilio_settings messages_plivo_settings
             messages_textanywhere_settings messages_smsgateway_settings google_calendar_settings].freeze

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "every settings page renders its text fields with a name and the stored value" do
    login_admin
    PAGES.each do |page|
      get "/#{page}"
      next unless response.status == 200

      # The page's own settings form only: the LDAP page also carries an import
      # form whose user settings post under the same parameter name.
      scope = "form[action$='/save'] "
      fields = css_select("#{scope}input[type=text][name^='settings['], #{scope}input:not([type])[name^='settings['], #{scope}textarea[name^='settings[']")
      names = fields.map { |field| field["name"][/settings\[([^\]]+)\]/, 1] }.uniq
      next if names.empty?

      names.each { |name| Setting.set(name, "probe #{name}") }
      get "/#{page}"
      names.each do |name|
        assert_select "#{scope}[name='settings[#{name}]']", 1, "#{page}: #{name} should render once"
        field = css_select("#{scope}[name='settings[#{name}]']").first
        shown = field.name == "textarea" ? field.text : field["value"]
        assert_equal "probe #{name}", shown, "#{page}: #{name} does not show its stored value"
      end

      # Nothing on the page is left in the jQuery shape: a control with a data
      # field but no name never posts.
      assert_select "[data-field]:not([name]):not([id^='embed-'])", 0, "#{page}: unnamed data-field control"
    end
  end
  test "the notifications page renders each notification's texts from the record" do
    notification = Notification.create!(title: "probe title", event: "coming_up", short_text: "probe short",
                                        long_text: "probe long", audiences: [ "customer" ], channels: [ "email" ])
    login_admin
    get "/messages_notifications"
    assert_select "input[name='notification[title]'][value='probe title']"
    assert_select "input[name='notification[short_text]'][value='probe short']"
    assert_select "textarea[name='notification[long_text]']", text: "probe long"
    assert_select "input[name='notification[id]'][value='#{notification.id}']"
  end
end
