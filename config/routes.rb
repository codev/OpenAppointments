# Routes mirror EA's CodeIgniter {controller}/{method} URIs because the ported JS
# builds URLs with App.Utils.Url.siteUrl.
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Auth
  get "login" => "login#index", as: :login
  post "login/validate" => "login#validate"
  get "logout" => "logout#index", as: :logout
  get "recovery" => "recovery#index", as: :recovery
  post "recovery/perform" => "recovery#perform"
  get "recovery/reset" => "recovery#reset", as: :recovery_reset
  post "recovery/complete" => "recovery#complete"

  # Backend calendar
  get "calendar" => "calendar#index", as: :calendar
  get "calendar/reschedule/:appointment_hash" => "calendar#reschedule"
  post "calendar/get_calendar_appointments" => "calendar#get_calendar_appointments"
  post "calendar/get_calendar_appointments_for_table_view" => "calendar#get_calendar_appointments_for_table_view"
  post "calendar/save_appointment" => "calendar#save_appointment"
  post "calendar/delete_appointment" => "calendar#delete_appointment"
  post "calendar/save_unavailability" => "calendar#save_unavailability"
  post "calendar/delete_unavailability" => "calendar#delete_unavailability"
  post "calendar/save_working_plan_exception" => "calendar#save_working_plan_exception"
  post "calendar/delete_working_plan_exception" => "calendar#delete_working_plan_exception"

  # Backend CRUD pages (EA pattern: page GET + find/search/store/update/destroy).
  # EA declares find as GET but the ported JS clients $.post it, so find takes both.
  # Unavailabilities has no page in EA, only the JSON endpoints.
  %w[customers services service_categories providers secretaries admins
     unavailabilities blocked_periods webhooks].each do |resource|
    get resource => "#{resource}#index" unless resource == "unavailabilities"
    match "#{resource}/find" => "#{resource}#find", via: [ :get, :post ]
    post "#{resource}/search" => "#{resource}#search"
    post "#{resource}/store" => "#{resource}#store"
    post "#{resource}/update" => "#{resource}#update"
    post "#{resource}/destroy" => "#{resource}#destroy"
  end

  # 10to8 import page
  get "import" => "import#index"
  get "import/export" => "import#export"
  post "import/analyze" => "import#analyze"
  post "import/start" => "import#start"
  get "import/status" => "import#status"
  post "import/reset" => "import#reset"

  # Record pictures (cards display mode)
  %w[providers secretaries admins services service_categories].each do |resource|
    post "#{resource}/:id/picture" => "#{resource}#save_picture"
  end

  # Public booking wizard
  root "booking#index"
  get "booking" => "booking#index"
  get "booking/reschedule/:appointment_hash" => "booking#reschedule"
  post "booking/get_available_hours" => "booking#get_available_hours"
  get "booking/get_unavailable_dates" => "booking#get_unavailable_dates"
  post "booking/register" => "booking#register"
  get "booking_confirmation/of/:appointment_hash" => "booking_confirmation#of", as: :booking_confirmation
  # EA has no GET cancellation page: the frame form POSTs and non-POST/empty-reason requests get 403.
  post "booking_cancellation/of/:appointment_hash" => "booking_cancellation#of"
  get "captcha/altcha_challenge" => "captcha#altcha_challenge"
  post "consents/save" => "consents#save"
  post "privacy/delete_personal_information" => "privacy#delete_personal_information"
  post "localization/change_language" => "localization#change_language"

  # Settings pages
  %w[general_settings business_settings booking_settings legal_settings api_settings
     altcha_settings embed_settings google_calendar_settings google_analytics_settings
     matomo_analytics_settings jitsi_settings ldap_settings
     messages_settings messages_email_settings messages_twilio_settings
     messages_plivo_settings messages_textanywhere_settings].each do |resource|
    get resource => "#{resource}#index"
    post "#{resource}/save" => "#{resource}#save"
  end

  # Messages panel
  get "messages" => redirect("/messages_settings")
  get "messages_providers" => "messages_providers#index"
  get "messages_notifications" => "messages_notifications#index"
  post "messages_notifications/save" => "messages_notifications#save"
  post "messages_notifications/destroy" => "messages_notifications#destroy"
  get "messages_logs" => "messages_logs#index"
  get "unknown_inbox" => "unknown_inbox#index"
  post "customer_messages/find" => "customer_messages#find"
  post "customer_messages/send" => "customer_messages#send_message"
  post "business_settings/apply_global_working_plan" => "business_settings#apply_global_working_plan"
  post "altcha_settings/generate_key" => "altcha_settings#generate_key"
  post "ldap_settings/search" => "ldap_settings#search"
  get "integrations" => "integrations#index"
  get "about" => "about#index"
  get "account" => "account#index"
  post "account/save" => "account#save"
  post "account/validate_username" => "account#validate_username"

  # Inbound SMS webhooks (public; token in URL)
  post "messages/inbound/:channel/:token" => "inbound_messages#receive"

  # Google Calendar OAuth + sync management
  get "google/oauth/:provider_id" => "google#oauth"
  get "google/oauth_callback" => "google#oauth_callback", as: :google_oauth_callback
  post "google/get_google_calendars" => "google#get_google_calendars"
  post "google/select_google_calendar" => "google#select_google_calendar"
  post "google/disable_provider_sync" => "google#disable_provider_sync"
  # REST API v1 (EA route_api_resource pattern: GET, GET/:id, POST, PUT/:id, DELETE/:id).
  namespace :api do
    namespace :v1 do
      %w[appointments unavailabilities customers admins providers secretaries
         services service_categories webhooks blocked_periods working_plan_exceptions].each do |resource|
        get resource => "#{resource}#index"
        get "#{resource}/:id" => "#{resource}#show"
        post resource => "#{resource}#store"
        put "#{resource}/:id" => "#{resource}#update"
        delete "#{resource}/:id" => "#{resource}#destroy"
      end

      get "settings" => "settings#index"
      get "settings/:name" => "settings#show", constraints: { name: /[^\/]+/ }
      put "settings/:name" => "settings#update", constraints: { name: /[^\/]+/ }

      get "availabilities" => "availabilities#get"
    end
  end
end
