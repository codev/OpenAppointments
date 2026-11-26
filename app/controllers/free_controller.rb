# Free page: the List page's free rows alone, for every date of the booking
# window (today to the last bookable date), admins only. A free slot opens the
# appointment dialog as on List.
class FreeController < ApplicationController
  include BackendPage
  include CalendarPage

  layout "backend"

  # The longest range the page builds, however the dates are typed.
  MAX_DAYS = 180

  # GET /free?providers[]=(id)&from=YYYY-MM-DD&to=YYYY-MM-DD
  # Without providers every stylist is shown; a lone blank value means none.
  # Without dates the booking window is shown.
  def index
    return unless require_backend_page!(:system_settings)

    @providers = visible_providers.to_a
    @provider_ids = params.key?(:providers) ? Array(params[:providers]).reject(&:blank?).map(&:to_i) : nil
    @window = [ BookingWindows.business_today, BookingWindows.last_bookable_date ]
    @first, @last = date_range
    @columns = build_columns(@provider_ids ? @providers.select { |p| @provider_ids.include?(p.id) } : @providers)
    backend_page_vars(page_title: helpers.lang("free"), active_menu: "free")
    script_vars(first_weekday: Setting.get("first_weekday"), **popover_script_vars)
    html_vars(appointment_statuses: AppointmentStatus.rows, **field_display_flags)
    render :index
  end

  private

  # The ticked stylists in their shortest form for the filter form: nil when
  # every one is shown, a lone blank when none is.
  def provider_param
    return nil if @provider_ids.nil? || (@providers.map(&:id) - @provider_ids).empty?

    @provider_ids.presence || [ "" ]
  end
  helper_method :provider_param

  # The window's dates unless from or to is given; to never falls before from
  # or more than MAX_DAYS after it.
  def date_range
    first = parse_date(params[:from]) || @window.first
    last = parse_date(params[:to]) || @window.last
    [ first, last.clamp(first, first + MAX_DAYS) ]
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end

  def custom_range? = [ @first, @last ] != @window
  helper_method :custom_range?

  # [{ date:, days: [{ day: ProviderDay, entries: [free Entry] }] }] for the
  # dates with a free slot; stylists with none that day are left out. One
  # engine holds every stylist's events for the window. Only the free rows are
  # shown, so a day gets the unavailabilities (off all day means no free rows)
  # and nothing that would only make rows that are dropped.
  def build_columns(providers)
    engine = Availability::Engine.new
    engine.preload(providers, @first, @last)
    unavailabilities = Appointment.unavailabilities.where(id_users_provider: providers.map(&:id))
                                  .where("start_datetime <= ? AND end_datetime >= ?", @last.end_of_day, @first.beginning_of_day)
                                  .includes(:provider).to_a

    (@first..@last).filter_map do |date|
      days = providers.filter_map do |provider|
        day = ProviderDay.new(provider, date, appointments: [], blocked_periods: [], engine: engine,
                              unavailabilities: unavailabilities.select { |u| u.id_users_provider == provider.id && u.start_datetime.to_date <= date && u.end_datetime.to_date >= date })
        entries = day.entries.select { |entry| entry.kind == "free" }
        { day: day, entries: entries } if entries.any?
      end
      { date: date, days: days } if days.any?
    end
  end
end
