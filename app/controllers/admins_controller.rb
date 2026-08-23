# Admins admin: Rails views inside Turbo Frames.
class AdminsController < ApplicationController
  include UserPage

  PAGE = { resource: :users, menu: "users", title: "admins", role: Role::ADMIN,
           save_webhook: Webhooks::ADMIN_SAVE, delete_webhook: Webhooks::ADMIN_DELETE,
           saved: "admin_saved", deleted: "admin_deleted" }.freeze

  # EA prevents self-deletion.
  def destroy
    return super unless @record.id == session[:user_id].to_i

    redirect_to admins_path(selected: @record.id), alert: "You cannot delete your own account."
  end
end
