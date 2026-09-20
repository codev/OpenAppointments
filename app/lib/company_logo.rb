# The company logo is stored as a data URL setting and served from its own
# route so browsers cache it; the digest in the path changes with the image.
module CompanyLogo
  module_function

  def path
    value = Setting.get("company_logo").to_s
    return nil if value.blank?

    "/company_logo?v=#{Digest::MD5.hexdigest(value)[0, 12]}"
  end

  # [content type, bytes] from the data URL; nil when unset or malformed.
  def image
    match = Setting.get("company_logo").to_s.match(%r{\Adata:(image/[\w.+-]+);base64,(.+)\z}m)
    return nil unless match

    [ match[1], Base64.decode64(match[2]) ]
  end
end
