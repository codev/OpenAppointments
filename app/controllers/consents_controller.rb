# Consent log endpoint, port of EA's Consents controller.
class ConsentsController < ApplicationController
  # POST /consents/save
  def save
    consent = params.require(:consent).permit(:name, :email, :type, :id_users).to_h
    consent["ip"] = request.remote_ip

    # EA throttles per IP: skip creation when a consent was stored in the last 24 hours.
    last_consent = Consent.where(ip: consent["ip"]).order(created_at: :desc).first
    return render json: { success: true } if last_consent && last_consent.created_at > 24.hours.ago

    record = Consent.create!(consent)

    render json: { success: true, id: record.id }
  rescue StandardError => e
    json_exception(e)
  end
end
