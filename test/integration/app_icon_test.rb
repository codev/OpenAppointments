require "test_helper"

class AppIconTest < ActionDispatch::IntegrationTest
  test "layouts link the svg favicon with png fallbacks" do
    get "/"
    assert_select "link[rel=icon][type='image/svg+xml']"
    assert_select "link[rel=icon][type='image/x-icon']"

    get "/login"
    assert_select "link[rel=icon][type='image/svg+xml']"
  end

  test "the icon assets exist in the rendered sizes" do
    assert Rails.root.join("app/assets/images/logo.svg").exist?
    assert Rails.root.join("app/assets/images/logo.png").exist?
    assert Rails.root.join("app/assets/images/logo-16x16.png").exist?
    assert Rails.root.join("app/assets/images/favicon.ico").exist?
    assert Rails.root.join("app/assets/images/social-card.png").exist?
    assert Rails.root.join("public/icon.png").exist?
    assert Rails.root.join("public/icon.svg").exist?
    assert Rails.root.join("icon.png").exist?
  end

  test "the cloudron manifest points at the icon" do
    manifest = JSON.parse(Rails.root.join("CloudronManifest.json").read)
    assert_equal "file://icon.png", manifest["icon"]
  end

  test "mail still inlines a png logo" do
    appointment = appointments(:upcoming)
    settings = { company_name: "Test Company", company_link: "https://example.org",
                 company_email: "info@example.org", company_color: nil,
                 date_format: "DMY", time_format: "regular" }
    mail = AppointmentMailer.saved(
      appointment: appointment, service: appointment.service, provider: appointment.provider,
      customer: appointment.customer, settings: settings,
      recipient_email: appointment.customer.email, recipient_language: "english",
      recipient_timezone: "UTC", manage_mode: false,
      ics: IcsFile.stream(appointment, appointment.service, appointment.provider, appointment.customer),
      link_path: "/booking/reschedule/#{appointment.booking_hash}", role: :customer
    )
    logo = mail.attachments.inline["logo.png"]
    assert_not_nil logo
    assert_equal "image/png", logo.mime_type
  end

  test "the readme documents every icon site" do
    readme = Rails.root.join("README.md").read
    assert_match(/## Icons/, readme)
    %w[logo.svg logo.png favicon.ico social-card.png icon.png CloudronManifest].each do |token|
      assert_includes readme, token
    end
  end
end
