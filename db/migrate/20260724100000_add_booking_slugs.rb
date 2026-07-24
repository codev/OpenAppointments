class AddBookingSlugs < ActiveRecord::Migration[8.1]
  def up
    add_column :services, :booking_slug, :string
    add_column :users, :booking_slug, :string
    add_index :services, :booking_slug, unique: true
    add_index :users, :booking_slug, unique: true

    Service.reset_column_information
    User.reset_column_information
    say_with_time "backfilling booking slugs" do
      Service.unscoped.where(booking_slug: nil).find_each do |service|
        service.update_columns(booking_slug: BookingSlug.unique_for(Service))
      end
      User.providers.where(booking_slug: nil).find_each do |provider|
        provider.update_columns(booking_slug: BookingSlug.unique_for(User))
      end
    end
  end

  def down
    remove_index :services, :booking_slug
    remove_index :users, :booking_slug
    remove_column :services, :booking_slug
    remove_column :users, :booking_slug
  end
end
