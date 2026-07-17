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

  # EA's default controller is booking; placeholder until P4.
  root "login#index"
end
