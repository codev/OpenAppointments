class LoginController < ApplicationController
  layout "account"

  rate_limit to: 5, within: 5.minutes, only: :validate,
             with: -> { render json: { success: false, message: "Too many login attempts. Please try again in a few minutes." }, status: :too_many_requests }

  def index
    redirect_to calendar_path and return if logged_in?

    dest_url = session[:dest_url] || calendar_url
    script_vars(dest_url: dest_url)
    html_vars(
      page_title: helpers.lang("login"),
      base_url: request.base_url,
      dest_url: dest_url,
      company_name: Setting.get("company_name"),
      require_captcha: Setting.get("require_captcha"),
      altcha_enabled: Setting.get("altcha_enabled")
    )
  end

  # POST /login/validate. EA contract: {success: true} or {success: false, message:}.
  def validate
    username = params[:username].to_s
    password = params[:password].to_s

    if username.blank? || password.blank? ||
       !username.match?(/\A[a-zA-Z0-9_@.\-]+\z/) || username.length > 255 ||
       password.length > Passwords::MAX_LENGTH
      return json_response({ success: false, message: "Invalid credentials provided, please try again." })
    end

    user_data = Accounts.check_login(username, password)

    if user_data.nil?
      Rails.logger.info("Failed login attempt for username: #{username} from IP: #{request.remote_ip}")
      return json_response({ success: false, message: "Invalid credentials provided, please try again." })
    end

    log_in(user_data)
    json_response({ success: true })
  end
end
