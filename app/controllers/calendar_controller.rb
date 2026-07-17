# Backend calendar. Placeholder until P5; exists now as the post-login landing page.
class CalendarController < ApplicationController
  before_action :require_session
  before_action -> { require_permission!(:view, :appointments) }

  def index
    render plain: "Calendar (P5)", layout: false
  end
end
