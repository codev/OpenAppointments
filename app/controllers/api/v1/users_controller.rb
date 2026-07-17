module Api
  module V1
    # Shared base for provider/secretary/admin API controllers: persists the User,
    # its UserSetting, and (per subclass) service/provider links. Reuses the P5
    # UserCrud helpers for settings, password rules, and working-plan-exception sync.
    class UsersController < ResourceController
      include UserCrud

      private

      def role_slug = raise NotImplementedError

      def base_scope
        User.where(id_roles: Role.find_by!(slug: role_slug).id)
      end

      def require_settings? = true

      def build_record(attrs)
        raise ArgumentError, "No settings property provided." if require_settings? && !attrs.key?("settings")

        @decoded = serializer_class.decode(attrs)
        user = User.new(user_columns(@decoded).merge(role: Role.find_by!(slug: role_slug)))
        user.last_name = user.first_name if user.last_name.blank?
        user
      end

      def apply_update(record, attrs)
        @decoded = serializer_class.decode(attrs)
        record.assign_attributes(user_columns(@decoded))
        record.last_name = record.first_name if record.last_name.blank?
      end

      def persist!(record)
        settings = (@decoded["settings"] || {}).dup
        validate_user_payload!(@decoded, settings, role_slug)
        validate_unique_role_email!(base_scope, @decoded.merge("id" => record.id)) if @decoded.key?("email")

        ActiveRecord::Base.transaction do
          record.save!
          apply_user_settings!(record, settings) if @decoded.key?("settings")
          apply_links(record)
        end
      end

      # Overridden by subclasses that manage service/provider links.
      def apply_links(_record); end

      def user_columns(decoded)
        decoded.except("settings", "services", "providers")
      end
    end
  end
end
