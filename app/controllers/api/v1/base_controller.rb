module Api
  module V1
    # EA API v1 base: Bearer token (api_token setting) or Basic auth resolving to an
    # admin user. Failure: 401 + WWW-Authenticate + EA's exact text body.
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Basic::ControllerMethods

      DEFAULT_LENGTH = 20

      before_action :authenticate_api!

      # EA's json_exception returns every failure as {success: false, message}; only a
      # missing record is a 404. Declared broad-first so the specific handler wins.
      rescue_from StandardError do |error|
        render json: { success: false, message: error.message }, status: :internal_server_error
      end
      rescue_from ActiveRecord::RecordNotFound do
        head :not_found
      end

      private

      def authenticate_api!
        header = request.headers["Authorization"].to_s

        if header.start_with?("Bearer ")
          token = header.delete_prefix("Bearer ")
          api_token = Setting.get("api_token").to_s
          return if api_token.present? && ActiveSupport::SecurityUtils.secure_compare(token, api_token)
        elsif header.start_with?("Basic ")
          credentials = authenticate_with_http_basic do |username, password|
            Accounts.check_login(username, password)
          end
          return if credentials && credentials[:role_slug] == Role::ADMIN
        end

        response.set_header("WWW-Authenticate", 'Basic realm="OpenAppointments"')
        render plain: "You are not authorized to use the API.", status: :unauthorized
      end

      # EA Api library params: q, page/length, sort (+/- prefixes), fields, with.
      def api_keyword = params[:q].presence

      def api_length = (params[:length].presence || DEFAULT_LENGTH).to_i

      def api_offset
        page = (params[:page].presence || 1).to_i
        (page - 1) * api_length
      end

      # Order clauses mapped through the serializer; unknown fields silently skipped (EA).
      def api_order(serializer)
        sort = params[:sort].presence
        return nil unless sort

        clauses = sort.split(",").filter_map do |raw|
          direction = raw.start_with?("-") ? "DESC" : "ASC"
          api_field = raw.sub(/\A[+\- ]/, "").strip
          db_field = serializer.db_field(api_field)
          "#{db_field} #{direction}" if db_field
        end
        clauses.presence&.join(", ")
      end

      def api_fields = params[:fields].presence&.split(",")&.map(&:strip)

      def api_with = params[:with].presence&.split(",")&.map(&:strip)

      def project_fields(payload)
        fields = api_fields
        return payload unless fields

        payload.is_a?(Array) ? payload.map { |row| row.slice(*fields) } : payload.slice(*fields)
      end

      def render_one(payload, status: :ok)
        render json: project_fields(payload), status: status
      end
    end
  end
end
