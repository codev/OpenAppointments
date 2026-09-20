# Login rate limiting kept in the cache: failed attempts are counted per IP
# and per username for a window, and once a count reaches its limit every
# attempt fails until the window passes. The maintainer hears about it once.
module LoginThrottle
  module_function

  WINDOW = 15.minutes
  IP_LIMIT = 20
  USERNAME_LIMIT = 5

  def blocked?(ip, username)
    count("ip", ip) >= IP_LIMIT || count("user", username) >= USERNAME_LIMIT
  end

  # Counts a failure; true the moment a limit is reached.
  def record_failure(ip, username)
    bump("ip", ip) == IP_LIMIT || bump("user", username) == USERNAME_LIMIT
  end

  # A successful login clears the username's count; the IP count stays.
  def clear_username(username)
    Rails.cache.delete(key("user", username))
  end

  def count(scope, value)
    Rails.cache.read(key(scope, value)).to_i
  end

  def bump(scope, value)
    total = count(scope, value) + 1
    Rails.cache.write(key(scope, value), total, expires_in: WINDOW)
    total
  end

  def key(scope, value)
    "login-failures/#{scope}/#{value.to_s.downcase}"
  end
end
