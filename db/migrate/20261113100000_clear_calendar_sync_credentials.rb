# The Google Calendar and CalDAV sync credentials are no longer used; the
# columns stay (a SQLite column drop rebuilds the table and cascades deletes)
# but their values and the Google settings rows go.
class ClearCalendarSyncCredentials < ActiveRecord::Migration[8.1]
  SETTINGS = %w[google_sync_feature google_client_id google_client_secret google_meet_link_generation].freeze

  def up
    UserSetting.update_all(google_sync: false, google_token: nil, google_calendar: nil,
                           caldav_sync: false, caldav_url: nil, caldav_username: nil, caldav_password: nil,
                           caldav_calendar: nil)
    Setting.where(name: SETTINGS).delete_all
  end

  def down; end
end
