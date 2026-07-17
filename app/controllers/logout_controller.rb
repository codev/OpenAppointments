class LogoutController < ApplicationController
  layout "account"

  def index
    log_out
    html_vars(
      page_title: helpers.lang("log_out"),
      company_name: Setting.get("company_name")
    )
  end
end
