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

  # Backend (placeholder until P5)
  get "calendar" => "calendar#index", as: :calendar

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
end
