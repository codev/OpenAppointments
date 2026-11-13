module Api
  module V1
    class ProviderSerializer < UserSerializer
      MAP = UserSerializer::MAP.merge("isPrivate" => "is_private").freeze

      class << self
        def encode(record)
          payload = super
          payload["services"] = record.services.map(&:id)
          payload
        end

        # Full provider settings sub-object (feed range and plan), EA shape.
        def settings_encode(settings)
          {
            "username" => settings.username,
            "notifications" => bool(settings.notifications),
            "syncFutureDays" => settings.sync_future_days&.to_i,
            "syncPastDays" => settings.sync_past_days&.to_i,
            "workingPlan" => parse_json(settings.working_plan),
            "workingPlanExceptions" => EaRows.working_plan_exceptions_api(settings.id_users)
          }
        end

        def decode(params, base = {})
          attrs = super
          attrs["services"] = params["services"] if params.key?("services")
          attrs
        end

        def settings_decode(settings)
          out = super
          return out if settings.blank?

          out["sync_future_days"] = settings["syncFutureDays"] if settings.key?("syncFutureDays")
          out["sync_past_days"] = settings["syncPastDays"] if settings.key?("syncPastDays")
          out["working_plan"] = settings["workingPlan"].to_json if settings.key?("workingPlan")
          if settings.key?("workingPlanExceptions")
            out["working_plan_exceptions"] = settings["workingPlanExceptions"].to_json
          end
          out
        end

        def parse_json(value)
          value.present? ? JSON.parse(value) : nil
        end
      end
    end
  end
end
