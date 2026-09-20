# The component reference page: every semantic component with its markup,
# rendered with the current theme. Routed in development and test only.
class StyleguideController < ApplicationController
  layout "styleguide"

  def index
    html_vars(page_title: "Style guide")
  end
end
