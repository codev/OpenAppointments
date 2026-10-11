# Permission checks against the role bitmask columns, mirroring EA's can()/cannot().
module Authorization
  extend ActiveSupport::Concern

  included do
    helper_method :can?, :cannot?, :inbox_access?
  end

  def can?(action, resource)
    session_role&.can?(action, resource) || false
  end

  def cannot?(action, resource)
    !can?(action, resource)
  end

  # The Inbox is an admin task list, as are its message actions.
  def inbox_access?
    session[:role_slug] == Role::ADMIN
  end

  def require_permission!(action, resource)
    return if can?(action, resource)

    respond_to do |format|
      format.html { head :forbidden }
      format.json { render json: { success: false, message: "Forbidden" }, status: :forbidden }
    end
  end
end
