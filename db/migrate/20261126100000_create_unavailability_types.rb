# Busy time types: a named, coloured kind for an unavailability (meeting, leave,
# admin), and the group that ties the rows saved together for several providers.
class CreateUnavailabilityTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :unavailability_types do |t|
      t.string :name, null: false
      t.string :color, default: "#7cbae8"
      t.integer :position, default: 0, null: false
      t.timestamps
    end
    add_index :unavailability_types, :name, unique: true

    add_reference :appointments, :unavailability_type, foreign_key: { on_delete: :nullify }
    add_column :appointments, :unavailability_group, :string
    add_index :appointments, :unavailability_group
  end
end
