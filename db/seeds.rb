# Roles and default settings ported from EA 1.6.0 (migration 001 + settings migrations 002-069).
# Idempotent: safe to re-run.

roles = {
  Role::ADMIN => { name: "Administrator", is_admin: true, appointments: 15, customers: 15, services: 15,
                   users: 15, system_settings: 15, user_settings: 15, webhooks: 15, blocked_periods: 15 },
  Role::PROVIDER => { name: "Provider", is_admin: false, appointments: 15, customers: 15, services: 0,
                      users: 0, system_settings: 0, user_settings: 15, webhooks: 0, blocked_periods: 0 },
  Role::CUSTOMER => { name: "Customer", is_admin: false, appointments: 0, customers: 0, services: 0,
                      users: 0, system_settings: 0, user_settings: 0, webhooks: 0, blocked_periods: 0 },
  Role::SECRETARY => { name: "Secretary", is_admin: false, appointments: 15, customers: 15, services: 0,
                       users: 0, system_settings: 0, user_settings: 15, webhooks: 0, blocked_periods: 0 }
}

roles.each do |slug, attrs|
  Role.find_or_create_by!(slug: slug) { |role| role.assign_attributes(attrs) }
end

default_working_plan = %w[monday tuesday wednesday thursday friday saturday sunday].index_with {
  { "start" => "09:00", "end" => "18:00", "breaks" => [ { "start" => "14:30", "end" => "15:00" } ] }
}.to_json

ldap_field_mapping = {
  "name" => "displayname", "email" => "mail",
  "phone_number" => "telephonenumber", "username" => "cn"
}.to_json

disable_booking_message =
  '<p style="text-align: center;">Thanks for stopping by!</p>' \
  '<p style="text-align: center;">We are not accepting new appointments at the moment, ' \
  "please check back again later.</p>"

settings = {
  # Company (installer overrides these)
  "company_name" => "Company Name",
  "company_email" => "info@example.org",
  "company_link" => "https://example.org",
  "company_logo" => "",
  "company_color" => "#39824f",
  "company_working_plan" => default_working_plan,

  # Booking / scheduling
  "book_advance_timeout" => "30",
  "future_booking_limit" => "90",
  "display_any_provider" => "1",
  "booking_display_mode" => "dropdown",
  "require_phone_or_email" => "1",
  "captcha_provider" => "altcha",
  "turnstile_site_key" => "",
  "turnstile_secret_key" => "",
  "allow_iframe_embedding" => "0",
  "iframe_embed_origin" => "",
  "disable_booking" => "0",
  "disable_booking_message" => disable_booking_message,
  "first_weekday" => "sunday",
  "appointment_status_options" => '["Booked", "Confirmed", "Rescheduled", "Cancelled", "Draft"]',

  # Booking form fields
  "display_email" => "1", "require_email" => "0",
  "display_phone_number" => "1", "require_phone_number" => "0",
  "display_address" => "1", "require_address" => "0",
  "display_city" => "1", "require_city" => "0",
  "display_zip_code" => "1", "require_zip_code" => "0",
  "display_notes" => "1", "require_notes" => "0",

  # Custom fields
  **(1..5).flat_map { |i|
    [ [ "display_custom_field_#{i}", "0" ], [ "require_custom_field_#{i}", "0" ], [ "label_custom_field_#{i}", "" ] ]
  }.to_h,

  # Display / formatting
  "date_format" => "DMY",
  "time_format" => "regular",
  "theme" => "default",
  "display_login_button" => "1",
  "default_language" => "english",
  "default_timezone" => "UTC",

  # Notifications / privacy / legal
  "customer_notifications" => "1",
  "require_captcha" => "0",
  "display_cookie_notice" => "0",
  "cookie_notice_content" => "Cookie notice content.",
  "display_terms_and_conditions" => "0",
  "terms_and_conditions_content" => "Terms and conditions content.",
  "display_privacy_policy" => "0",
  "privacy_policy_content" => "Privacy policy content.",
  "display_delete_personal_information" => "0",
  "data_retention_days" => "0",
  "limit_customer_access" => "0",

  # Integrations
  "api_token" => "",
  "google_analytics_code" => "",
  "matomo_analytics_url" => "",
  "matomo_analytics_site_id" => "1",
  "google_sync_feature" => "0",
  "google_client_id" => "",
  "google_client_secret" => "",
  "ldap_is_active" => "0",
  "ldap_host" => "",
  "ldap_port" => "",
  "ldap_user_dn" => "",
  "ldap_password" => "",
  "ldap_base_dn" => "",
  "ldap_filter" =>
    "(&(objectClass=*)(|(cn={{KEYWORD}})(sn={{KEYWORD}})(mail={{KEYWORD}})(givenName={{KEYWORD}})(uid={{KEYWORD}})))",
  "ldap_field_mapping" => ldap_field_mapping,
  "altcha_enabled" => "0",
  "altcha_hmac_key" => "",
  "altcha_max_number" => "100000",
  "altcha_expires" => "300"
}

settings.each do |name, value|
  Setting.find_or_create_by!(name: name) { |setting| setting.value = value }
end
