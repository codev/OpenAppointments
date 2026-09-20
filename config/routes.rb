# Routes mirror EA's CodeIgniter {controller}/{method} URIs because the ported JS
# builds URLs with App.Utils.Url.siteUrl.
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "company_logo" => "company_logo#show"

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
  get "appointments" => "appointments#index", as: :appointments
  # Event dialog forms (rendered into the calendar pages' event frame)
  resources :appointments, only: %i[new create edit update] do
    member do
      get :remove, action: :remove_form
      post :remove
    end
  end
  resources :unavailabilities, only: %i[new create edit update destroy], controller: "unavailabilities_form"
  get "calendar/reschedule/:appointment_hash" => "calendar#reschedule"
  post "calendar/get_calendar_appointments" => "calendar#get_calendar_appointments"
  post "calendar/save_appointment" => "calendar#save_appointment"
  post "calendar/delete_appointment" => "calendar#delete_appointment"
  post "calendar/cancel_appointment" => "calendar#cancel_appointment"
  post "calendar/save_unavailability" => "calendar#save_unavailability"
  post "calendar/delete_unavailability" => "calendar#delete_unavailability"
  post "calendar/save_working_plan_exception" => "calendar#save_working_plan_exception"
  post "calendar/delete_working_plan_exception" => "calendar#delete_working_plan_exception"

  # Repeating appointments (backend only); the list and cancel form render in a frame
  get "appointment_series" => "appointment_series#index", as: :appointment_series
  get "appointment_series/:id/cancel" => "appointment_series#cancel_form", as: :cancel_form_appointment_series
  post "appointment_series/:id/reschedule" => "appointment_series#reschedule"
  post "appointment_series/:id/cancel" => "appointment_series#cancel", as: :cancel_appointment_series

  # Old backend page URL after the assistant rename
  get "secretaries" => redirect("/assistants")

  # Drag-to-reorder for the booking page ordering
  %w[services service_categories providers].each do |resource|
    post "#{resource}/reorder" => "#{resource}#reorder"
    post "#{resource}/sort_alphabetically" => "#{resource}#sort_alphabetically"
  end

  # Converted to Rails views + Turbo Frames; category and customer search stay as
  # JSON for the services page select and the appointments modal.
  resources :service_categories, only: %i[index new create edit update destroy] do
    post :search, on: :collection
  end
  resources :customers, only: %i[index new create edit update destroy] do
    post :search, on: :collection
  end
  resources :blocked_periods, only: %i[index new create edit update destroy]
  resources :webhooks, only: %i[index new create edit update destroy]
  resources :admins, only: %i[index new create edit update destroy]
  resources :assistants, only: %i[index new create edit update destroy]
  resources :providers, only: %i[index new create edit update destroy] do
    post :regenerate_link, on: :member
  end
  resources :services, only: %i[index new create edit update destroy] do
    post :regenerate_link, on: :member
  end

  # 10to8 import page
  get "import" => "import#index"
  post "import/export" => "import#export"
  get "import/export_status" => "import#export_status"
  get "import/download_backup" => "import#download_backup"
  get "import/report" => "import#report"
  get "import/customer_report" => "import#customer_report"
  post "import/analyze" => "import#analyze"
  post "import/start" => "import#start"
  get "import/status" => "import#status"
  post "import/reset" => "import#reset"


  # Public booking wizard
  root "booking#index"
  get "booking" => "booking#index"
  get "booking/reschedule/:appointment_hash" => "booking#reschedule"
  post "booking/confirm" => "booking#confirm"
  post "booking/register" => "booking#register"
  get "booking_confirmation/of/:appointment_hash" => "booking_confirmation#of", as: :booking_confirmation
  get "booking_confirmation/ics/:appointment_hash" => "booking_confirmation#ics", as: :booking_confirmation_ics
  # EA has no GET cancellation page: the frame form POSTs and non-POST/empty-reason requests get 403.
  post "booking_cancellation/of/:appointment_hash" => "booking_cancellation#of"
  post "booking_cancellation/late/:appointment_hash" => "booking_cancellation#late"
  get "captcha/altcha_challenge" => "captcha#altcha_challenge"
  post "consents/save" => "consents#save"
  post "privacy/delete_personal_information" => "privacy#delete_personal_information"
  post "localization/change_language" => "localization#change_language"

  # Settings pages
  %w[general_settings business_settings booking_settings theme_settings legal_settings api_settings
     altcha_settings embed_settings google_calendar_settings umami_analytics_settings
     google_analytics_settings matomo_analytics_settings jitsi_settings ldap_settings
     messages_settings messages_email_settings messages_twilio_settings
     messages_plivo_settings messages_textanywhere_settings
     messages_smsgateway_settings].each do |resource|
    get resource => "#{resource}#index"
    post "#{resource}/save" => "#{resource}#save"
  end

  # Theme preview sample (rendered in the Theme settings cards)
  get "theme_settings/preview" => "theme_settings#preview"

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
  post "customer_messages/mark_read" => "customer_messages#mark_read"
  get "inbox" => "inbox#index"
  post "messages/:id/mark_read" => "messages#mark_read"
  post "business_settings/apply_global_working_plan" => "business_settings#apply_global_working_plan"
  post "altcha_settings/generate_key" => "altcha_settings#generate_key"
  post "messages_smsgateway_settings/test_sms" => "messages_smsgateway_settings#test_sms"
  post "ldap_settings/search" => "ldap_settings#search"
  post "ldap_settings/import" => "ldap_settings#import"
  get "integrations" => "integrations#index"
  get "about" => "about#index"
  get "account" => "account#index"
  post "account/save" => "account#save"

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
      %w[appointments unavailabilities customers admins providers assistants
         services service_categories webhooks blocked_periods working_plan_exceptions].each do |resource|
        get resource => "#{resource}#index"
        get "#{resource}/:id" => "#{resource}#show"
        post resource => "#{resource}#store"
        put "#{resource}/:id" => "#{resource}#update"
        delete "#{resource}/:id" => "#{resource}#destroy"
      end

      # EA compat: the old secretaries routes stay as aliases for assistants.
      get "secretaries" => "assistants#index"
      get "secretaries/:id" => "assistants#show"
      post "secretaries" => "assistants#store"
      put "secretaries/:id" => "assistants#update"
      delete "secretaries/:id" => "assistants#destroy"

      get "settings" => "settings#index"
      get "settings/:name" => "settings#show", constraints: { name: /[^\/]+/ }
      put "settings/:name" => "settings#update", constraints: { name: /[^\/]+/ }

      get "availabilities" => "availabilities#get"
    end
  end
end
