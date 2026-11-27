# Service descriptions became rich text; the plain ones written before are
# wrapped in paragraphs so their line breaks still show.
class WrapPlainServiceDescriptions < ActiveRecord::Migration[8.1]
  def up
    Service.where.not(description: [ nil, "" ]).where.not("description LIKE '%<%'").find_each do |service|
      service.update_columns(description: ActionController::Base.helpers.simple_format(service.description))
    end
  end

  def down; end
end
