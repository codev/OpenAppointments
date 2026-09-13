class LoginController < ApplicationController
  layout "account"

  rate_limit to: 5, within: 5.minutes, only: :validate, with: :too_many_attempts

  def index
    redirect_to calendar_path and return if logged_in?

    html_vars(page_title: helpers.lang("login"), company_name: Setting.get("company_name"))
  end

  # POST /login/validate. The login form (form=1) redirects to the page the
  # visitor wanted; other callers get EA's {success: true} or {success: false, message:}.
  def validate
    case Captcha.for_login
    when "altcha"
      return captcha_failed(:altcha_verification, "altcha_verification_failed") unless AltchaChallenge.verify(params[:altcha_payload])
    when "turnstile"
      unless TurnstileChallenge.verify(params[:cf_turnstile_response], request.remote_ip)
        return captcha_failed(:turnstile_verification, "turnstile_verification_failed")
      end
    end

    username = params[:username].to_s
    password = params[:password].to_s

    if username.blank? || password.blank? ||
       !username.match?(/\A[a-zA-Z0-9_@.\-]+\z/) || username.length > 255 ||
       password.length > Passwords::MAX_LENGTH
      return login_failed
    end

    user_data = Accounts.check_login(username, password)

    if user_data.nil?
      Rails.logger.info("Failed login attempt for username: #{username} from IP: #{request.remote_ip}")
      return login_failed
    end

    dest_url = session[:dest_url] || calendar_url
    log_in(user_data)
    form_post? ? redirect_to(dest_url) : json_response({ success: true })
  end

  private

  def form_post? = params[:form].present?

  def login_failed
    message = "Invalid credentials provided, please try again."
    return json_response({ success: false, message: message }) unless form_post?

    redirect_to login_path, alert: helpers.lang("login_failed")
  end

  def captcha_failed(key, lang_key)
    return json_response({ key => false }) unless form_post?

    redirect_to login_path, alert: helpers.lang(lang_key)
  end

  def too_many_attempts
    message = "Too many login attempts. Please try again in a few minutes."
    return redirect_to(login_path, alert: message) if form_post?

    render json: { success: false, message: message }, status: :too_many_requests
  end
end
