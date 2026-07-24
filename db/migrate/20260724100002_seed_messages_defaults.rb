# Data for existing installs: messages settings rows, the inbound webhook token,
# the No Show status option and the three default notifications. Fresh installs
# get the same from db/seeds.rb.
class SeedMessagesDefaults < ActiveRecord::Migration[8.1]
  def up
    Messaging::Defaults::SETTINGS.each do |name, value|
      Setting.find_or_create_by!(name: name) { |setting| setting.value = value }
    end
    Setting.find_or_create_by!(name: "messages_inbound_token") do |setting|
      setting.value = Messaging::Defaults.inbound_token
    end

    options = JSON.parse(Setting.get("appointment_status_options", "[]"))
    unless options.include?("No Show")
      Setting.set("appointment_status_options", JSON.generate(options + [ "No Show" ]))
    end

    Notification.reset_column_information
    Messaging::Defaults.create_notifications!
  end

  def down; end
end
