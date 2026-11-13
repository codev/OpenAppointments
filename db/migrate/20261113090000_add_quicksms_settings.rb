# Existing installs get the QuickSMS settings rows; fresh installs take them
# from db/seeds.rb with the other defaults.
class AddQuicksmsSettings < ActiveRecord::Migration[8.1]
  def up
    Messaging::Defaults::SETTINGS.select { |name, _| name.start_with?("messages_quicksms_") }.each do |name, value|
      Setting.find_or_create_by!(name: name) { |setting| setting.value = value }
    end
  end

  def down; end
end
