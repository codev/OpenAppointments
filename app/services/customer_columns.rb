# Customer custom field columns shared by the reports: the fields whose
# Display switch is on, headed by their configured labels.
module CustomerColumns
  module_function

  # labels: key -> header text. Returns [[attribute, header], ...].
  def custom_fields(labels)
    (1..5).filter_map do |i|
      next unless Setting.get("display_custom_field_#{i}").to_s == "1"

      [ "custom_field_#{i}", Setting.get("label_custom_field_#{i}").presence || "#{labels.call('custom_field')} ##{i}" ]
    end
  end
end
