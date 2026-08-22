# Appointments page: one day column per provider, the EA "table" calendar view.
class AppointmentsController < ApplicationController
  include BackendPage
  include CalendarPage

  layout "backend"

  def index
    render_calendar_page(page_title: "appointments", active_menu: "appointments")
  end
end
