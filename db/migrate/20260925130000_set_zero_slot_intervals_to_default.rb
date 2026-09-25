# A slot interval must be at least 1 minute; the booking engine already read
# 0 as 15, so stored zeros become 15 and nothing changes for customers.
class SetZeroSlotIntervalsToDefault < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE services SET slot_interval = 15 WHERE slot_interval IS NULL OR slot_interval < 1"
  end

  def down; end
end
