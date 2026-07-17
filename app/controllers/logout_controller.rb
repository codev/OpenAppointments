class LogoutController < ApplicationController
  def index
    log_out
    render :index
  end
end
