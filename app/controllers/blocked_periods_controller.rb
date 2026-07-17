# Blocked periods admin CRUD, port of EA's Blocked_periods controller.
class BlockedPeriodsController < ApplicationController
  include BackendPage

  layout "backend"

  ALLOWED_FIELDS = %w[id name start_datetime end_datetime notes].freeze

  before_action :require_session, except: [ :index ]

  def index
    return unless require_backend_page!(:blocked_periods)

    backend_page_vars(page_title: helpers.lang("blocked_periods"), active_menu: "blocked_periods")
    script_vars(first_weekday: Setting.get("first_weekday"))
    render :index
  end

  # POST /blocked_periods/search
  def search
    raise ArgumentError, "Forbidden" if cannot?(:view, :blocked_periods)

    blocked_periods = search_blocked_periods(params[:keyword].to_s, params.fetch(:limit, 1000).to_i,
                                             params.fetch(:offset, 0).to_i)

    render json: blocked_periods.map { |period| EaRows.blocked_period_row(period) }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /blocked_periods/store
  def store
    raise ArgumentError, "Forbidden" if cannot?(:add, :blocked_periods)

    save_blocked_period(BlockedPeriod.new)
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # GET/POST /blocked_periods/find
  def find
    raise ArgumentError, "Forbidden" if cannot?(:view, :blocked_periods)

    blocked_period_id = params.require(:blocked_period_id).to_i
    raise ArgumentError, "Invalid blocked period ID provided." unless blocked_period_id.positive?

    render json: EaRows.blocked_period_row(BlockedPeriod.find(blocked_period_id))
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /blocked_periods/update
  def update
    raise ArgumentError, "Forbidden" if cannot?(:edit, :blocked_periods)

    save_blocked_period(BlockedPeriod.find(permitted_blocked_period.fetch("id")))
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # POST /blocked_periods/destroy
  def destroy
    raise ArgumentError, "Forbidden" if cannot?(:delete, :blocked_periods)

    blocked_period_id = params.require(:blocked_period_id).to_i
    raise ArgumentError, "Invalid blocked period ID provided." unless blocked_period_id.positive?

    blocked_period = BlockedPeriod.find(blocked_period_id)
    row = EaRows.blocked_period_row(blocked_period)
    blocked_period.destroy!
    Webhooks.trigger(Webhooks::BLOCKED_PERIOD_DELETE, row)

    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  private

  def permitted_blocked_period
    value = params.require(:blocked_period)
    value = value.permit(*ALLOWED_FIELDS.map(&:to_sym)).to_h if value.is_a?(ActionController::Parameters)
    value
  end

  def save_blocked_period(blocked_period)
    blocked_period.assign_attributes(permitted_blocked_period.except("id"))
    blocked_period.save!
    Webhooks.trigger(Webhooks::BLOCKED_PERIOD_SAVE, EaRows.blocked_period_row(blocked_period))
    render json: { success: true, id: blocked_period.id }
  end

  def search_blocked_periods(keyword, limit, offset)
    scope = BlockedPeriod.order(updated_at: :desc).limit(limit).offset(offset)
    return scope if keyword.blank?

    pattern = "%#{BlockedPeriod.sanitize_sql_like(keyword)}%"
    scope.where("name LIKE :pattern OR notes LIKE :pattern", pattern: pattern)
  end
end
