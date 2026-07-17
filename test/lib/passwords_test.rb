require "test_helper"

class PasswordsTest < ActiveSupport::TestCase
  test "hash produces bcrypt verifiable by verify" do
    hash = Passwords.hash("secret7pass")
    assert Passwords.bcrypt?(hash)
    assert Passwords.verify(nil, "secret7pass", hash)
    assert_not Passwords.verify(nil, "wrong", hash)
  end

  test "verify accepts EA legacy iterated sha256 hashes" do
    salt = "a" * 64
    legacy = Passwords.legacy_hash(salt, "oldpassword")
    assert Passwords.verify(salt, "oldpassword", legacy)
    assert_not Passwords.verify(salt, "wrong", legacy)
  end

  test "legacy hash matches EA algorithm for a known vector" do
    # Independent implementation of EA's password_helper.php scheme.
    salt = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    half = salt.length / 2
    expected = Digest::SHA256.hexdigest(salt[0, half] + "pass" + salt[half..])
    100_000.times { expected = Digest::SHA256.hexdigest(expected) }
    assert_equal expected, Passwords.legacy_hash(salt, "pass")
  end

  test "needs_rehash for legacy and wrong-cost hashes" do
    assert Passwords.needs_rehash?("abcdef0123456789")
    assert Passwords.needs_rehash?(BCrypt::Password.create("x", cost: 4))
    assert_not Passwords.needs_rehash?(BCrypt::Password.create("x", cost: Passwords::BCRYPT_COST))
  end

  test "rejects overlong passwords" do
    hash = Passwords.hash("secret7pass")
    assert_not Passwords.verify(nil, "a" * 101, hash)
    assert_raises(ArgumentError) { Passwords.hash("a" * 101) }
  end
end
