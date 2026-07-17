module Api
  module V1
    class AdminsController < UsersController
      self.serializer_class = AdminSerializer
      self.save_webhook = Webhooks::ADMIN_SAVE
      self.delete_webhook = Webhooks::ADMIN_DELETE

      private

      def role_slug = Role::ADMIN
    end
  end
end
