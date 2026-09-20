# Folds one customer record into another: appointments, repeating
# appointments and messages move across, blank details on the kept record are
# filled from the merged one, and the merged record is deleted.
module CustomerMerge
  module_function

  FILLABLE = %w[email phone_number mobile_number address city state zip_code timezone language
                custom_field_1 custom_field_2 custom_field_3 custom_field_4 custom_field_5].freeze

  # The customer with that email or phone number (as typed or in E.164).
  def find_target(query, except:)
    query = query.strip
    return nil if query.blank?

    scope = User.customers.where.not(id: except.id)
    scope.find_by(email: query) || User.customer_by_phone(query, scope)
  end

  def run(source, target)
    User.transaction do
      Appointment.where(id_users_customer: source.id).update_all(id_users_customer: target.id)
      AppointmentSeries.where(id_users_customer: source.id).update_all(id_users_customer: target.id)
      Message.where(customer_id: source.id).update_all(customer_id: target.id)
      FILLABLE.each { |field| target[field] = source[field] if target[field].blank? && source[field].present? }
      target.notes = [ target.notes, source.notes ].compact_blank.join("\n") if source.notes.present? && !target.notes.to_s.include?(source.notes)
      target.save!
      source.destroy!
    end
    target
  end
end
