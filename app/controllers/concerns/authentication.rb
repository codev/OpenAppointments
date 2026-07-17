# Session-based auth mirroring EA: session stores user_id, user_email, username,
# timezone, language, role_slug.
module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :logged_in?, :session_role
  end

  def log_in(user_data)
    reset_session
    user_data.each { |key, value| session[key] = value }
  end

  def log_out
    reset_session
  end

  def current_user
    return nil unless session[:user_id]

    @current_user ||= User.find_by(id: session[:user_id])
  end

  def logged_in?
    session[:user_id].present?
  end

  def session_role
    @session_role ||= Role.find_by(slug: session[:role_slug]) if session[:role_slug]
  end

  def require_session
    return if logged_in?

    session[:dest_url] = request.original_url if request.get? || request.head?
    respond_to do |format|
      format.html { redirect_to login_path }
      format.json { render json: { success: false, message: "Not authorized" }, status: :unauthorized }
    end
  end
end
