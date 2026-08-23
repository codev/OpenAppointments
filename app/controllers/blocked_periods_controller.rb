# Blocked periods admin: Rails views inside Turbo Frames.
class BlockedPeriodsController < ApplicationController
  include CrudPage

  PAGE = { resource: :blocked_periods, menu: "blocked_periods", title: "blocked_periods", per_page: 20,
           save_webhook: Webhooks::BLOCKED_PERIOD_SAVE, delete_webhook: Webhooks::BLOCKED_PERIOD_DELETE,
           saved: "blocked_period_saved", deleted: "blocked_period_deleted" }.freeze

  def new
    @record = BlockedPeriod.new(start_datetime: Date.current.beginning_of_day,
                                end_datetime: Date.tomorrow.beginning_of_day)
    @editing = true
    render_page
  end

  private

  def record_scope = BlockedPeriod.order(updated_at: :desc)

  def filter(scope, keyword)
    return scope if keyword.blank?

    pattern = "%#{BlockedPeriod.sanitize_sql_like(keyword)}%"
    scope.where("name LIKE :pattern OR notes LIKE :pattern", pattern: pattern)
  end

  def record_params
    params.require(:blocked_period).permit(:name, :start_datetime, :end_datetime, :notes)
  end
end
