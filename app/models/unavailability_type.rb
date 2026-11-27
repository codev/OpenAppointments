# A kind of busy time (unavailability) with its own colour: Meeting, Time off,
# Admin. Managed on Business Settings; a deleted type leaves its busy times in
# place without a type.
class UnavailabilityType < ApplicationRecord
  # The calendar's colour for busy time without a type.
  DEFAULT_COLOR = "#879DB4".freeze
  # Colours from the colour picker's palette.
  DEFAULT_LIST = { "Meeting" => "#7cbae8", "Time off" => "#e3e3e3", "Admin" => "#ebe07c", "Travel" => "#abe9a4" }.freeze

  has_many :unavailabilities, class_name: "Appointment", inverse_of: :unavailability_type, dependent: :nullify

  validates :name, presence: true, uniqueness: true

  scope :ordered, -> { order(:position, :id) }

  # New types join the end of the list.
  before_create { self.position = self.class.maximum(:position).to_i + 1 if position.to_i.zero? && self.class.exists? }

  def self.rows = ordered.map { |t| { "id" => t.id, "name" => t.name, "color" => t.color } }

  # Fresh install / reset: the default list.
  def self.seed!
    DEFAULT_LIST.each_with_index do |(name, color), position|
      find_or_create_by!(name: name) { |type| type.assign_attributes(color: color, position: position) }
    end
  end

  # Name lookup used by the restore and the service conversion; unknown names
  # are created at the end of the list.
  def self.resolve(name, color: nil)
    name = name.to_s.strip
    return nil if name.empty?

    find_by(name: name) || create!(name: name, color: color.presence || DEFAULT_COLOR)
  end

  def color_or_default = color.presence || DEFAULT_COLOR
end
