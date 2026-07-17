# Shared behavior for backend pages, mirroring EA's controller boilerplate:
# unauthenticated GETs redirect to login (with dest_url), authenticated users
# without the view privilege get 403, and common page vars are populated.
module BackendPage
  extend ActiveSupport::Concern

  private

  def require_backend_page!(resource)
    session[:dest_url] = request.original_url

    unless logged_in?
      redirect_to login_path
      return false
    end

    unless can?(:view, resource)
      head :forbidden
      return false
    end

    true
  end

  def backend_page_vars(page_title:, active_menu:)
    html_vars(
      page_title: page_title,
      active_menu: active_menu,
      user_display_name: current_user&.full_name,
      timezone: session[:timezone],
      grouped_timezones: helpers.grouped_timezones,
      privileges: session_role.permissions
    )
    script_vars(
      user_id: session[:user_id],
      role_slug: session[:role_slug],
      date_format: Setting.get("date_format"),
      time_format: Setting.get("time_format"),
      default_language: Setting.get("default_language"),
      default_timezone: Setting.get("default_timezone")
    )
  end

  def secretary_provider_ids
    @secretary_provider_ids ||=
      session[:role_slug] == Role::SECRETARY ? current_user.providers.map(&:id) : []
  end

  # EA Permissions::has_customer_access.
  def customer_access?(customer_id)
    return true if session[:role_slug] == Role::ADMIN || Setting.get("limit_customer_access") != "1"

    case session[:role_slug]
    when Role::PROVIDER
      Appointment.where(id_users_provider: session[:user_id], id_users_customer: customer_id).exists?
    when Role::SECRETARY
      Appointment.where(id_users_provider: secretary_provider_ids, id_users_customer: customer_id).exists?
    else
      false
    end
  end

  # EA Calendar::check_event_permissions.
  def check_event_permissions!(provider_id)
    case session[:role_slug]
    when Role::SECRETARY
      head :forbidden unless secretary_provider_ids.include?(provider_id.to_i)
    when Role::PROVIDER
      head :forbidden unless session[:user_id].to_i == provider_id.to_i
    end
  end
end
