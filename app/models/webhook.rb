class Webhook < ApplicationRecord
  validates :name, :url, presence: true

  # actions is a comma-separated list of WEBHOOK_* event names, as in EA.
  def action_list
    actions.to_s.split(",").map(&:strip)
  end

  def handles?(action)
    action_list.include?(action.to_s)
  end
end
