class RecoveryController < ApplicationController
  layout "account"

  rate_limit to: 5, within: 5.minutes, only: [ :perform, :complete ], with: :too_many_attempts

  def index
    html_vars(
      page_title: helpers.lang("forgot_your_password"),
      dest_url: session[:dest_url] || calendar_url,
      company_name: Setting.get("company_name")
    )
  end

  # POST /recovery/perform. Always answers success to prevent enumeration; the
  # form (form=1) comes back to the page with the sent message.
  def perform
    return captcha_failed(recovery_path) unless captcha_ok?

    username = params[:username].to_s
    email = params[:email].to_s

    begin
      reset_data = Accounts.generate_reset_token(username, email)
      reset_link = recovery_reset_url(token: reset_data[:token])
      AccountMailer.password_reset_link(reset_data[:email], reset_link).deliver_later
    rescue ActiveRecord::RecordNotFound
      Rails.logger.info("Password recovery attempted for non-existent user: #{username} / #{email}")
    end

    form_post? ? redirect_to(recovery_path, notice: helpers.lang("reset_link_sent_with_email")) : json_response({ success: true })
  end

  # GET /recovery/reset?token=... EA branches: malformed token -> invalid_reset_token,
  # unknown/expired token -> invalid_or_expired_token, valid token -> the reset form.
  def reset
    token = params[:token].to_s
    return redirect_to recovery_path if token.blank?

    html_vars(page_title: helpers.lang("reset_password"))

    if !token.match?(/\A[a-f0-9]{64}\z/)
      html_vars(token_valid: false, error_message: helpers.lang("invalid_reset_token"))
    elsif Accounts.validate_reset_token(token).nil?
      html_vars(token_valid: false, error_message: helpers.lang("invalid_or_expired_token"))
    else
      html_vars(
        token_valid: true,
        token: token,
        company_name: Setting.get("company_name")
      )
    end
    render :reset
  end

  # POST /recovery/complete with token, password, password_confirm.
  def complete
    token = params[:token].to_s
    password = params[:password].to_s
    password_confirm = params[:password_confirm].to_s
    return captcha_failed(recovery_reset_path(token: token)) unless captcha_ok?

    if password != password_confirm
      return complete_failed(token, "The provided passwords do not match.", helpers.lang("passwords_mismatch"))
    end

    if password.length < Passwords::MIN_LENGTH
      return complete_failed(token, "The password must be at least #{Passwords::MIN_LENGTH} characters long.",
                             helpers.lang("password_length_notice").sub("$number", Passwords::MIN_LENGTH.to_s))
    end

    Accounts.reset_password_with_token(token, password)
    form_post? ? redirect_to(login_path, notice: helpers.lang("password_reset_success")) : json_response({ success: true })
  rescue ArgumentError => e
    complete_failed(token, e.message, e.message)
  end

  private

  def form_post? = params[:form].present?

  def captcha_ok?
    case Captcha.for_login
    when "altcha" then AltchaChallenge.verify(params[:altcha_payload])
    when "turnstile" then TurnstileChallenge.verify(params[:cf_turnstile_response], request.remote_ip)
    else true
    end
  end

  def captcha_failed(path)
    key = Captcha.for_login == "altcha" ? "altcha_verification_failed" : "turnstile_verification_failed"
    form_post? ? redirect_to(path, alert: helpers.lang(key)) : json_response({ success: false, message: helpers.lang(key) })
  end

  def complete_failed(token, message, flash_message)
    return json_response({ success: false, message: message }) unless form_post?

    redirect_to recovery_reset_path(token: token), alert: flash_message
  end

  def too_many_attempts
    message = "Too many attempts. Please try again in a few minutes."
    return redirect_to(recovery_path, alert: message) if form_post?

    render json: { success: false, message: message }, status: :too_many_requests
  end
end
