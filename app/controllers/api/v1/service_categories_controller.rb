module Api
  module V1
    class ServiceCategoriesController < ResourceController
      self.model_class = ServiceCategory
      self.serializer_class = ServiceCategorySerializer
      self.save_webhook = Webhooks::SERVICE_CATEGORY_SAVE
      self.delete_webhook = Webhooks::SERVICE_CATEGORY_DELETE
    end
  end
end
