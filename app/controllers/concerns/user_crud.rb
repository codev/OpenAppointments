# Shared save/search logic for the provider/secretary/admin CRUD controllers,
# mirroring EA's Providers/Secretaries/Admins_model save flows and validations.
module UserCrud
  extend ActiveSupport::Concern

  CALENDAR_VIEWS = %w[default table].freeze

  private

  # EA *_model::validate: password rules and calendar view check. Username and
  # email uniqueness are enforced by the models / validate_unique_role_email.
  def validate_user_payload!(user_params, settings, role_label)
    password = settings["password"]
    if password.present? && password.length < Passwords::MIN_LENGTH
      raise ArgumentError,
            "The #{role_label} password must be at least #{Passwords::MIN_LENGTH} characters long."
    end
    if user_params["id"].blank? && password.blank?
      raise ArgumentError, "The #{role_label} password cannot be empty when inserting a new record."
    end
    if settings["calendar_view"].present? && CALENDAR_VIEWS.exclude?(settings["calendar_view"])
      raise ArgumentError, "The provided calendar view is invalid: #{settings['calendar_view']}"
    end
  end

  # EA email uniqueness check within the role.
  def validate_unique_role_email!(scope, user_params)
    exists = scope.where(email: user_params["email"])
                  .where.not(id: user_params["id"].presence || 0).exists?
    raise ArgumentError, "The provided email address is already in use, please use a different one." if exists
  end

  # EA *_model::set_settings: only whitelisted keys arrive; password is hashed
  # only when provided; working_plan_exceptions sync the working_plan_exceptions table.
  def apply_user_settings!(user, settings)
    settings = settings.dup
    exceptions_json = settings.delete("working_plan_exceptions")
    password = settings.delete("password")

    record = user.settings || user.build_settings
    record.assign_attributes(settings)
    record.password = Passwords.hash(password) if password.present?
    record.save!

    sync_working_plan_exceptions!(user, exceptions_json) unless exceptions_json.nil?
  end

  # EA Providers_model::set_settings working_plan_exceptions branch: upsert the
  # posted camelCase exceptions, delete the ones no longer present.
  def sync_working_plan_exceptions!(user, exceptions_json)
    exceptions = begin
      JSON.parse(exceptions_json.to_s)
    rescue JSON::ParserError
      []
    end
    exceptions = [] unless exceptions.is_a?(Array)

    existing_ids = WorkingPlanException.where(id_users_provider: user.id).pluck(:id)
    kept_ids = exceptions.map do |exception|
      start_date = exception["startDate"]
      end_date = exception["endDate"].presence || start_date
      raise ArgumentError, "Start date and end date are required for working plan exception." if start_date.blank?

      record = exception["id"].present? ? WorkingPlanException.find(exception["id"]) : WorkingPlanException.new
      record.assign_attributes(
        start_date: start_date, end_date: end_date,
        start_time: exception["startTime"], end_time: exception["endTime"],
        breaks: (exception["breaks"] || []).to_json,
        id_users_provider: user.id
      )
      record.save!
      record.id
    end

    WorkingPlanException.where(id: existing_ids - kept_ids).delete_all
  end

  # EA user model search: LIKE across the common user columns.
  def search_users(scope, keyword, limit, offset)
    scope = scope.order(updated_at: :desc).limit(limit).offset(offset)
    return scope if keyword.blank?

    pattern = "%#{User.sanitize_sql_like(keyword)}%"
    scope.where(<<~SQL.squish, pattern: pattern)
      users.name LIKE :pattern OR email LIKE :pattern
      OR phone_number LIKE :pattern OR mobile_number LIKE :pattern OR address LIKE :pattern
      OR city LIKE :pattern OR state LIKE :pattern OR zip_code LIKE :pattern OR notes LIKE :pattern
    SQL
  end

  def positive_id!(value, label)
    id = value.to_i
    raise ArgumentError, "Invalid #{label} ID provided." unless id.positive?

    id
  end
end
