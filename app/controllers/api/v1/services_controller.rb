module Api
  module V1
    class ServicesController < ResourceController
      self.model_class = Service
      self.serializer_class = ServiceSerializer
      self.save_webhook = Webhooks::SERVICE_SAVE
      self.delete_webhook = Webhooks::SERVICE_DELETE
    end
  end
end
