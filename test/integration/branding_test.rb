require "test_helper"

class BrandingTest < ActionDispatch::IntegrationTest
  test "booking page is branded OpenAppointments" do
    get "/"
    assert_response :success
    assert_match "OpenAppointments", response.body
    assert_no_match(/easy!appointments/i, response.body)
  end

  test "login page carries no old brand" do
    get "/login"
    assert_response :success
    assert_no_match(/easy!appointments/i, response.body)
  end

  test "about page shows the new name" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/about"
    assert_response :success
    assert_match "OpenAppointments", response.body
    # The backend footer carries a deliberate Easy!Appointments attribution;
    # the old brand must not appear anywhere else.
    assert_equal 1, response.body.scan(/easy!appointments/i).length
  end

  test "backend footer credits Codev and links the AGPL license" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/about"
    assert_select "#footer a[href='https://codev.uk/']", text: "Codev"
    assert_select "#footer a[href*='agpl-3.0']", text: /AGPL-3.0/
    assert_select "#footer #select-language"
  end

  test "no locale contains the old brand name" do
    I18n.available_locales.each do |locale|
      payload = I18n.t("ea", locale: locale, default: {}).values.grep(String).join(" ")
      assert_no_match(/easy!appointments/i, payload, "old brand present in locale #{locale}")
    end
  end

  test "built-in mail templates carry no old brand" do
    mail = AccountMailer.password_reset_link("someone@example.org", "https://example.org/reset")
    body = mail.html_part.body.decoded
    assert_no_match(/easy!appointments/i, body)
    assert_match "OpenAppointments", body

    message = Message.create!(direction: "outgoing", channel: "email", audience: "customer",
                              to_address: "someone@example.org", subject: "Hello", body: "Hi there")
    outgoing = MessagesMailer.outgoing(message)
    assert_no_match(/easy!appointments/i, outgoing.html_part.body.decoded)
  end
end
