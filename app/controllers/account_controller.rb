# Port of EA's Account controller: the current user's profile + settings.
class AccountController < ApplicationController
  include BackendPage

  layout "backend"

  ALLOWED_USER_FIELDS = %w[name email mobile_number phone_number
                           address city state zip_code notes timezone language].freeze
  ALLOWED_USER_SETTING_FIELDS = %w[username password notifications calendar_view].freeze

  before_action :require_session, except: [ :index ]

  def index
    return unless require_backend_page!(:user_settings)

    backend_page_vars(page_title: helpers.lang("settings"), active_menu: "system_settings")
    script_vars(account: account_payload(current_user))
    html_vars(available_languages: Localization.available_languages)
    render :index
  end

  # POST /account/save
  def save
    raise ArgumentError, "You do not have the required permissions for this task." if cannot?(:edit, :user_settings)

    account = params.require(:account)
    user = User.find(session[:user_id])
    settings = user.settings || user.build_settings

    user.assign_attributes(account.permit(*ALLOWED_USER_FIELDS).to_h)
    settings_attributes = account.fetch(:settings, {}).permit(*ALLOWED_USER_SETTING_FIELDS).to_h
    password = settings_attributes.delete("password")
    settings.assign_attributes(settings_attributes)
    settings.password = Passwords.hash(password) if password.present?

    user.save!
    settings.save!

    session[:user_email] = user.email
    session[:username] = settings.username
    session[:timezone] = user.timezone
    session[:language] = user.language

    render json: { success: true }
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e)
  end

  # POST /account/validate_username
  def validate_username
    username = params.require(:username)
    user_id = params[:user_id].presence

    scope = UserSetting.where(username: username)
    scope = scope.where.not(id_users: user_id) if user_id

    render json: { is_valid: !scope.exists? }
  rescue ArgumentError => e
    json_exception(e)
  end

  private

  # EA users_model->find + filter_sensitive_user_data.
  def account_payload(user)
    row = EaRows.user_row(user)
    row["settings"] =
      if user.settings
        user.settings.attributes.except("id_users", "created_at", "updated_at", *EaRows::SENSITIVE_SETTINGS)
      else
        {}
      end
    row
  end
end
