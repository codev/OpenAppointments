# Per-request attributes. actor names who is doing the work for the activity
# log: a logged-in user's display, or one of the Activity actor tokens.
class Current < ActiveSupport::CurrentAttributes
  attribute :actor
end
