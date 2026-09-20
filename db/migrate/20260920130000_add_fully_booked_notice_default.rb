# Existing installs get the default Fully Booked Notice; fresh installs take it
# from db/seeds.rb with the other defaults.
class AddFullyBookedNoticeDefault < ActiveRecord::Migration[8.1]
  def up
    return if Setting.exists?(name: "fully_booked_notice_content")

    Setting.create!(name: "fully_booked_notice_content",
                    value: "<p>#{I18n.t('ea.fully_booked_notice_default', locale: :en)}</p>")
    Rails.cache.delete("setting/fully_booked_notice_content")
  end

  def down; end
end
