# Existing installs get the payments settings rows; fresh installs take them
# from db/seeds.rb with the other defaults.
class AddPaymentsSettings < ActiveRecord::Migration[8.1]
  def up
    Payments::Defaults::SETTINGS.each do |name, value|
      Setting.find_or_create_by!(name: name) { |setting| setting.value = value }
    end
  end

  def down; end
end
