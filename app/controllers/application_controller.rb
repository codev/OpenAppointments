class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include ScriptVars
  include LocaleSelection

  before_action { script_vars(default_script_vars) }

  # EA JS posts the CSRF token as a `csrf_token` body param (double-submit port).
  self.request_forgery_protection_token = :csrf_token

  allow_browser versions: :modern

  private

  def json_response(payload, status: :ok)
    render json: payload, status: status
  end

  # EA's json_exception shape: {success: false, message:}
  def json_exception(error, status: :internal_server_error)
    render json: { success: false, message: error.message }, status: status
  end

  # Backend list searches: report the unpaged total in a header (for the
  # pagination bar), then apply the page window.
  def paginate_search(scope, limit, offset)
    response.set_header("X-Total-Count", scope.except(:includes, :order).count.to_s)
    scope.limit(limit).offset(offset)
  end
end
