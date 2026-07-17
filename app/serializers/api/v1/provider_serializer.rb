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

        # Full provider settings sub-object (google/caldav/sync/plan), EA shape.
        def settings_encode(settings)
          {
            "username" => settings.username,
            "notifications" => bool(settings.notifications),
            "calendarView" => settings.calendar_view,
            "googleSync" => bool(settings.google_sync),
            "googleToken" => settings.google_token,
            "googleCalendar" => settings.google_calendar,
            "caldavSync" => bool(settings.caldav_sync),
            "caldavUrl" => settings.caldav_url,
            "caldavUsername" => settings.caldav_username,
            "caldavPassword" => settings.caldav_password,
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

          out["google_sync"] = settings["googleSync"] if settings.key?("googleSync")
          out["google_token"] = settings["googleToken"] if settings.key?("googleToken")
          out["google_calendar"] = settings["googleCalendar"] if settings.key?("googleCalendar")
          out["caldav_sync"] = settings["caldavSync"] if settings.key?("caldavSync")
          out["caldav_url"] = settings["caldavUrl"] if settings.key?("caldavUrl")
          out["caldav_username"] = settings["caldavUsername"] if settings.key?("caldavUsername")
          out["caldav_password"] = settings["caldavPassword"] if settings.key?("caldavPassword")
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
