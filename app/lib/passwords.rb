# Password hashing ported from EA's password_helper.php.
# New hashes are bcrypt (cost 12). Legacy EA hashes are sha256(salt_left + password +
# salt_right) iterated 100,000 times; verify supports both so imported EA credentials work.
module Passwords
  MIN_LENGTH = 7
  MAX_LENGTH = 100
  BCRYPT_COST = 12
  LEGACY_ITERATIONS = 100_000

  module_function

  def hash(password)
    raise ArgumentError, "password too long" if password.length > MAX_LENGTH

    BCrypt::Password.create(password, cost: BCRYPT_COST)
  end

  def verify(salt, password, stored_hash)
    return false if password.to_s.length > MAX_LENGTH || stored_hash.blank?

    if bcrypt?(stored_hash)
      BCrypt::Password.new(stored_hash) == password
    else
      ActiveSupport::SecurityUtils.secure_compare(legacy_hash(salt.to_s, password), stored_hash)
    end
  end

  def needs_rehash?(stored_hash)
    !bcrypt?(stored_hash) || BCrypt::Password.new(stored_hash).cost != BCRYPT_COST
  end

  def bcrypt?(stored_hash)
    stored_hash.to_s.match?(/\A\$2[ayb]\$/)
  end

  def legacy_hash(salt, password)
    half = salt.length / 2
    digest = Digest::SHA256.hexdigest(salt[0, half].to_s + password + salt[half..].to_s)
    LEGACY_ITERATIONS.times { digest = Digest::SHA256.hexdigest(digest) }
    digest
  end
end
