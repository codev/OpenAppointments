# Appointment statuses, managed on Business Settings. The special kinds drive
# behaviour (default status, freeing slots, notification triggers) and can be
# renamed but not deleted; custom ones are labels only.
class AppointmentStatus < ApplicationRecord
  enum :kind, { custom: 0, booked: 1, rescheduled: 2, cancelled: 3, late_cancel: 4, no_show: 5 }

  SPECIAL_KINDS = kinds.keys - %w[custom]
  FREE_SLOT_KINDS = %w[rescheduled cancelled late_cancel].freeze
  DEFAULT_NAMES = { "booked" => "Booked", "rescheduled" => "Rescheduled", "cancelled" => "Cancelled",
                    "late_cancel" => "Late Cancel", "no_show" => "No Show" }.freeze
  DEFAULT_LIST = [ "Booked", "Confirmed", "Rescheduled", "Cancelled", "Draft", "No Show", "Late Cancel" ].freeze

  has_many :appointments, foreign_key: :status_id, inverse_of: :appointment_status, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :kind, inclusion: { in: kinds.keys }
  validate :one_per_special_kind
  before_destroy :forbid_special

  scope :ordered, -> { order(:position, :id) }
  scope :free_slot, -> { where(kind: FREE_SLOT_KINDS) }

  def self.of(kind) = find_by(kind: kind)

  # Name lookup used by API, imports and series; unknown names become custom.
  def self.resolve(name)
    name = name.to_s.strip
    return nil if name.empty?

    find_by(name: name) || create!(name: name, kind: "custom", position: maximum(:position).to_i + 1)
  end

  def self.names = ordered.pluck(:name)

  def self.rows = ordered.map { |s| { "id" => s.id, "name" => s.name, "kind" => s.kind } }

  # Fresh install / reset: the default list with every special kind present.
  def self.seed!
    DEFAULT_LIST.each_with_index do |name, position|
      kind = DEFAULT_NAMES.key(name) || "custom"
      next if exists?(name: name) || (kind != "custom" && exists?(kind: kind))

      create!(name: name, kind: kind, position: position)
    end
  end

  # Apply the settings page list [{id, name, kind}]: rename, reorder, add customs,
  # delete missing customs. Special kinds are never removed.
  def self.apply!(rows)
    transaction do
      keep = []
      rows.each_with_index do |row, position|
        status = row["id"].present? ? find_by(id: row["id"]) : nil
        name = row["name"].to_s.strip
        next if name.empty?

        if status
          status.update!(name: name, position: position)
        else
          status = create!(name: name, kind: "custom", position: position)
        end
        keep << status.id
      end
      where.not(id: keep).where(kind: "custom").destroy_all
    end
  end

  def special? = !custom?

  def frees_slot? = FREE_SLOT_KINDS.include?(kind)

  private

  def one_per_special_kind
    return if custom?
    return unless self.class.where(kind: kind).where.not(id: id).exists?

    errors.add(:kind, "already exists")
  end

  def forbid_special
    return if custom?

    errors.add(:base, "special statuses cannot be deleted")
    throw :abort
  end
end
