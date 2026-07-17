# GDPR personal data removal, port of EA's Privacy controller.
class PrivacyController < ApplicationController
  rate_limit to: 3, within: 15.minutes, only: :delete_personal_information,
             with: -> {
               render json: { success: false, message: "Too many deletion attempts. Please try again later." },
                      status: :internal_server_error
             }

  # POST /privacy/delete_personal_information
  # The customer_token is cached by BookingController#index in manage mode.
  def delete_personal_information
    return head :forbidden unless Setting.get("display_delete_personal_information") == "1"

    customer_token = params[:customer_token].to_s
    raise ArgumentError, "Invalid customer token value provided." if customer_token.blank?
    raise ArgumentError, "Invalid customer token format." unless customer_token.match?(/\A[a-fA-F0-9]{32}\z/)

    customer_id = Rails.cache.read("customer-token-#{customer_token}")
    raise ArgumentError, "Customer ID does not exist, please reload the page and try again." if customer_id.blank?

    User.customers.find(customer_id).destroy! # Appointments cascade with the customer.

    Rails.logger.info("Customer personal information deleted. Customer ID: #{customer_id} IP: #{request.remote_ip}")

    render json: { success: true }
  rescue StandardError => e
    json_exception(e)
  end
end
