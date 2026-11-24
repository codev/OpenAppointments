# A line on the admin Activity page. kind is one of Activity::KINDS, actor is a
# user display or an Activity actor token, summary and details are plain text.
class ActivityEvent < ApplicationRecord
  belongs_to :appointment, optional: true
  belongs_to :customer, class_name: "User", optional: true
  belongs_to :message, optional: true
  belongs_to :user, optional: true

  validates :kind, :actor, :summary, presence: true

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :of_kind, ->(kind) { where(kind: kind) }
end
