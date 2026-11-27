# A service shown on the booking page that clients cannot book online: they
# see its description, staff book it in the backend.
class AddIsBookableToServices < ActiveRecord::Migration[8.1]
  def change
    add_column :services, :is_bookable, :boolean, default: true, null: false
  end
end
