# Serves the uploaded company logo; pages link to it via CompanyLogo.path.
class CompanyLogoController < ApplicationController
  def show
    content_type, bytes = CompanyLogo.image
    return head :not_found unless bytes

    expires_in 1.year, public: true
    send_data bytes, type: content_type, disposition: "inline"
  end
end
