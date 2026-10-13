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

  # A session whose user has been deleted (e.g. by a database reset) is dead:
  # treat it as logged out and clear it so every page falls back to login.
  def logged_in?
    return false unless session[:user_id].present?
    return true if current_user

    reset_session
    false
  end

  def session_role
    @session_role ||= Role.find_by(slug: session[:role_slug]) if session[:role_slug]
  end

  DEST_URL_LIMIT = 1000

  # The page a logged out visitor asked for, for the login form to return to.
  # The session is a 4 KB cookie, so a longer URL is not kept and login lands
  # on the List instead.
  def remember_destination
    return unless request.get? || request.head?

    url = request.original_url
    session[:dest_url] = url.length <= DEST_URL_LIMIT ? url : nil
  end

  def require_session
    return if logged_in?

    remember_destination
    respond_to do |format|
      format.html { redirect_to login_path }
      format.json { render json: { success: false, message: "Not authorized" }, status: :unauthorized }
    end
  end
end
