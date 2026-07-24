# Database reset for the manage-data page. The default reset removes business
# data (appointments, customers, providers, secretaries, services, categories,
# consents, blocked periods, working plan exceptions) and keeps admin accounts
# and settings. A full reset also deletes admins, webhooks and all settings,
# reseeds the defaults and recreates the fresh-install administrator.
module ResetDatabase
  module_function

  def run(full: false)
    ActiveRecord::Base.transaction do
      Appointment.delete_all
      Consent.delete_all
      BlockedPeriod.delete_all
      WorkingPlanException.delete_all
      ServiceProviderLink.delete_all
      SecretaryProviderLink.delete_all
      Service.destroy_all
      ServiceCategory.destroy_all
      [ User.customers, User.providers, User.secretaries ].each do |scope|
        scope.find_each(&:destroy!)
      end

      if full
        Webhook.delete_all
        User.admins.find_each(&:destroy!)
        Setting.delete_all
      end

      # Inside the transaction: a failure rolls the whole reset back instead of
      # leaving the install half-wiped (e.g. no admin accounts).
      Rails.application.load_seed
      InstallAdmin.create if full
    end
    true
  end
end
