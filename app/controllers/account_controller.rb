# Port of EA's Account controller: the current user's profile + settings.
class AccountController < ApplicationController
  include BackendPage

  layout "backend"

  ALLOWED_USER_FIELDS = %w[name email mobile_number phone_number
                           address city state zip_code notes timezone language].freeze
  ALLOWED_USER_SETTING_FIELDS = %w[username password notifications].freeze

  before_action :require_session, except: [ :index ]

  def index
    return unless require_backend_page!(:user_settings)

    backend_page_vars(page_title: helpers.lang("settings"), active_menu: "system_settings")
    html_vars(require_password_change: current_user&.settings&.require_password_change == true)
    render :index
  end

  # POST /account/save. The page form (form=1) comes back with a flash; other
  # callers get EA's JSON.
  def save
    raise ArgumentError, "You do not have the required permissions for this task." if cannot?(:edit, :user_settings)

    account = params.require(:account)
    user = User.find(session[:user_id])
    settings = user.settings || user.build_settings

    user.assign_attributes(account.permit(*ALLOWED_USER_FIELDS).to_h)
    settings_attributes = account.fetch(:settings, {}).permit(*ALLOWED_USER_SETTING_FIELDS, :password_confirmation).to_h
    password = settings_attributes.delete("password")
    confirmation = settings_attributes.delete("password_confirmation")
    raise ArgumentError, helpers.lang("passwords_mismatch") if password.present? && !confirmation.nil? && password != confirmation
    if password.present? && password.length < Passwords::MIN_LENGTH
      raise ArgumentError, helpers.lang("password_length_notice").sub("$number", Passwords::MIN_LENGTH.to_s)
    end
    if UserSetting.where(username: settings_attributes["username"]).where.not(id_users: user.id).exists?
      raise ArgumentError, helpers.lang("username_already_exists")
    end
    settings.assign_attributes(settings_attributes)
    if password.present?
      settings.password = Passwords.hash(password)
      settings.require_password_change = false
    end

    user.save!
    settings.save!

    session[:user_email] = user.email
    session[:username] = settings.username
    session[:timezone] = user.timezone
    session[:language] = user.language

    params[:form].present? ? redirect_to("/account", notice: helpers.lang("settings_saved")) : render(json: { success: true })
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    params[:form].present? ? redirect_to("/account", alert: e.message) : json_exception(e)
  end


end
