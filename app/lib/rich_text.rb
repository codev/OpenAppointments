# HTML written by the rich text editor (service descriptions, the notices on
# the Legal Contents page) and rendered on the public pages, so it is
# sanitised whichever path writes it.
module RichText
  # The editor writes alignment as an inline style; the sanitiser keeps only
  # safe CSS properties within it.
  ATTRIBUTES = (Rails::HTML5::SafeListSanitizer.allowed_attributes + [ "style" ]).freeze

  def self.sanitize(html)
    Rails::HTML5::SafeListSanitizer.new.sanitize(html.to_s, attributes: ATTRIBUTES)
  end
end
