# Parses CHANGELOG.md for the about page release notes.
module Changelog
  module_function

  def entries
    text = Rails.root.join("CHANGELOG.md").read
    text.scan(/^## (\d+\.\d+\.\d+)\s*\n(.*?)(?=^## |\z)/m).map do |version, body|
      { version: version, notes: body.scan(/^- (.+)$/).flatten }
    end
  end
end
