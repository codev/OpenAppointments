module Api
  module V1
    class WorkingPlanExceptionsController < ResourceController
      self.model_class = WorkingPlanException
      self.serializer_class = WorkingPlanExceptionSerializer
    end
  end
end
