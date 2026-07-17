module Api
  module V1
    class BlockedPeriodsController < ResourceController
      self.model_class = BlockedPeriod
      self.serializer_class = BlockedPeriodSerializer
      self.save_webhook = Webhooks::BLOCKED_PERIOD_SAVE
      self.delete_webhook = Webhooks::BLOCKED_PERIOD_DELETE
    end
  end
end
