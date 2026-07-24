# Short unguessable slugs for public booking links (xxxx-xxxx). The alphabet is
# lowercase letters and digits minus the characters that read alike (0/o, 1/i/l).
module BookingSlug
  ALPHABET = "23456789abcdefghjkmnpqrstuvwxyz".chars.freeze
  FORMAT = /\A[#{ALPHABET.join}]{4}-[#{ALPHABET.join}]{4}\z/

  module_function

  def generate
    core = Array.new(8) { ALPHABET[SecureRandom.random_number(ALPHABET.size)] }.join
    "#{core[0, 4]}-#{core[4, 4]}"
  end

  # Collision-safe slug for the given model class (unique index backs this up).
  def unique_for(model)
    loop do
      slug = generate
      return slug unless model.unscoped.exists?(booking_slug: slug)
    end
  end
end
