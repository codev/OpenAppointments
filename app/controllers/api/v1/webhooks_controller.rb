module Api
  module V1
    # EA fires no webhook when webhooks themselves change.
    class WebhooksController < ResourceController
      self.model_class = Webhook
      self.serializer_class = WebhookSerializer
    end
  end
end
