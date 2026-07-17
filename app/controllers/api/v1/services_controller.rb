module Api
  module V1
    class ServicesController < ResourceController
      self.model_class = Service
      self.serializer_class = ServiceSerializer
      self.save_webhook = Webhooks::SERVICE_SAVE
      self.delete_webhook = Webhooks::SERVICE_DELETE

      private

      def with_loaders
        { "category" => ->(record) { raw_row(record.category) } }
      end
    end
  end
end
