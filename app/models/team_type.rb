class TeamType < ApplicationRecord
  has_neat_id :tmty
  has_paper_trail versions: { class_name: "AuditLog" }
  has_many :teams
  validates :name, presence: true

  def self.ransackable_attributes(auth_object = nil)
    [ "name", "updated_at" ]
  end

  def identifier_icon
    "tag"
  end
end
