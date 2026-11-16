# Payment state per appointment and the payment methods each service accepts
# (a comma separated list of method keys; empty means the default method).
class AddPaymentFields < ActiveRecord::Migration[8.1]
  def change
    add_column :appointments, :payment_method, :string
    add_column :appointments, :payment_reference, :string
    add_column :appointments, :paid_at, :datetime
    add_index :appointments, :payment_reference
    add_column :services, :payment_methods, :string
  end
end
