class Mentor < ApplicationRecord
  has_many :mentoring_sessions, dependent: :destroy

  def tags_array
    tags.to_s.split(",").map(&:strip)
  end
end
