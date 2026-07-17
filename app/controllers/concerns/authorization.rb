# Permission checks against the role bitmask columns, mirroring EA's can()/cannot().
module Authorization
  extend ActiveSupport::Concern

  included do
    helper_method :can?, :cannot?
  end

  def can?(action, resource)
    session_role&.can?(action, resource) || false
  end

  def cannot?(action, resource)
    !can?(action, resource)
  end

  def require_permission!(action, resource)
    return if can?(action, resource)

    respond_to do |format|
      format.html { head :forbidden }
      format.json { render json: { success: false, message: "Forbidden" }, status: :forbidden }
    end
  end
end
