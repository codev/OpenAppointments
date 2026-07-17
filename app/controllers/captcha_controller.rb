# Serves ALTCHA challenges for the booking/auth forms (utils/altcha.js fetches
# captcha/altcha_challenge). The legacy image captcha is not ported.
class CaptchaController < ApplicationController
  def altcha_challenge
    challenge = AltchaChallenge.create_challenge
    render json: {
      algorithm: challenge.algorithm,
      challenge: challenge.challenge,
      maxnumber: challenge.maxnumber,
      salt: challenge.salt,
      signature: challenge.signature
    }
  rescue RuntimeError => e
    render json: { success: false, message: e.message }, status: :internal_server_error
  end
end
