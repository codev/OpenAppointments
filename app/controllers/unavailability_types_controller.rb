# Busy time types admin: Rails views inside Turbo Frames, reached from Business settings.
class UnavailabilityTypesController < ApplicationController
  include CrudPage

  PAGE = { resource: :system_settings, menu: "unavailability_types", title: "unavailability_types", per_page: 50,
           saved: "unavailability_type_saved", deleted: "unavailability_type_deleted" }.freeze

  private

  def record_scope = UnavailabilityType.ordered

  def filter(scope, keyword)
    return scope if keyword.blank?

    scope.where("name LIKE ?", "%#{UnavailabilityType.sanitize_sql_like(keyword)}%")
  end

  def record_params
    params.require(:unavailability_type).permit(:name, :color)
  end
end
