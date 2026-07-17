class RecoveryController < ApplicationController
  layout "account"

  rate_limit to: 5, within: 5.minutes, only: [ :perform, :complete ],
             with: -> { render json: { success: false, message: "Too many attempts. Please try again in a few minutes." }, status: :too_many_requests }

  def index
    html_vars(
      page_title: helpers.lang("forgot_your_password"),
      dest_url: session[:dest_url] || calendar_url,
      company_name: Setting.get("company_name"),
      require_captcha: Setting.get("require_captcha"),
      altcha_enabled: Setting.get("altcha_enabled")
    )
  end

  # POST /recovery/perform. Always responds {success: true} to prevent enumeration.
  def perform
    username = params[:username].to_s
    email = params[:email].to_s

    begin
      reset_data = Accounts.generate_reset_token(username, email)
      reset_link = recovery_reset_url(token: reset_data[:token])
      AccountMailer.password_reset_link(reset_data[:email], reset_link).deliver_later
    rescue ActiveRecord::RecordNotFound
      Rails.logger.info("Password recovery attempted for non-existent user: #{username} / #{email}")
    end

    json_response({ success: true })
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
        company_name: Setting.get("company_name"),
        require_captcha: Setting.get("require_captcha"),
        altcha_enabled: Setting.get("altcha_enabled")
      )
    end
    render :reset
  end

  # POST /recovery/complete with token, password, password_confirm.
  def complete
    token = params[:token].to_s
    password = params[:password].to_s
    password_confirm = params[:password_confirm].to_s

    if password != password_confirm
      return json_response({ success: false, message: "The provided passwords do not match." })
    end

    if password.length < Passwords::MIN_LENGTH
      return json_response({ success: false,
                             message: "The password must be at least #{Passwords::MIN_LENGTH} characters long." })
    end

    Accounts.reset_password_with_token(token, password)
    json_response({ success: true })
  rescue ArgumentError => e
    json_response({ success: false, message: e.message })
  end
end
