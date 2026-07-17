# Account operations ported from EA's Accounts library.
module Accounts
  RESET_TOKEN_TTL = 1.hour

  module_function

  # Returns the EA session-data hash on success, nil on failure.
  # Rehashes legacy passwords to bcrypt on successful login.
  def check_login(username, password)
    settings = UserSetting.find_by(username: username)
    return nil unless settings
    return nil unless Passwords.verify(settings.salt, password, settings.password)

    if Passwords.needs_rehash?(settings.password)
      settings.update!(password: Passwords.hash(password))
    end

    user = settings.user
    {
      user_id: user.id,
      user_email: user.email,
      username: username,
      timezone: user.timezone.presence || Setting.get("default_timezone", "UTC"),
      language: user.language.presence || Setting.get("default_language", "english"),
      role_slug: user.role.slug
    }
  end

  # Returns {token:, email:} or raises if no matching user (caller swallows, EA-style).
  def generate_reset_token(username, email)
    settings = UserSetting.joins(:user).where(username: username, users: { email: email }).first
    raise ActiveRecord::RecordNotFound, "user not found" unless settings

    token = SecureRandom.hex(32)
    settings.update!(
      password_reset_token: Digest::SHA256.hexdigest(token),
      password_reset_expires: Time.now + RESET_TOKEN_TTL
    )
    { token: token, email: settings.user.email }
  end

  def validate_reset_token(token)
    UserSetting
      .where(password_reset_token: Digest::SHA256.hexdigest(token.to_s))
      .where("password_reset_expires > ?", Time.now)
      .first
  end

  def reset_password_with_token(token, new_password)
    settings = validate_reset_token(token)
    raise ArgumentError, "Invalid or expired password reset token." unless settings

    settings.update!(
      password: Passwords.hash(new_password),
      password_reset_token: nil,
      password_reset_expires: nil
    )
    true
  end
end
