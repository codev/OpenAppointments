# Business-data reset for the import page: removes appointments, customers,
# providers, secretaries, services, categories, consents, blocked periods and
# working plan exceptions. Admin accounts and settings survive; seeds re-run to
# restore any missing defaults.
module ResetDatabase
  module_function

  def run
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
    end
    Rails.application.load_seed
    true
  end
end
