module Api
  module V1
    class CustomersController < ResourceController
      self.serializer_class = CustomerSerializer
      self.save_webhook = Webhooks::CUSTOMER_SAVE
      self.delete_webhook = Webhooks::CUSTOMER_DELETE

      private

      def base_scope = User.customers

      def build_record(attrs)
        User.new(serializer_class.decode(attrs).merge(role: Role.find_by!(slug: Role::CUSTOMER)))
      end

      def persist!(record)
        record.last_name = record.first_name if record.last_name.blank?
        record.save!
      end
    end
  end
end
