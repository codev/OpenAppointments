module Api
  module V1
    # EA settings API: collection of {name, value}, GET/PUT by name.
    class SettingsController < BaseController
      def index
        settings = Setting.order(:name)
        keyword = api_keyword
        settings = settings.where("name LIKE :p OR value LIKE :p", p: "%#{Setting.sanitize_sql_like(keyword)}%") if keyword.present?
        settings = settings.limit(api_length).offset(api_offset)
        render json: settings.map { |setting| project_fields("name" => setting.name, "value" => setting.value) }
      end

      # EA returns {name, value} even for unknown names (value null).
      def show
        render json: { name: params[:name], value: Setting.get(params[:name]) }
      end

      def update
        Setting.set(params[:name], params[:value])
        render json: { name: params[:name], value: Setting.get(params[:name]) }
      end
    end
  end
end
