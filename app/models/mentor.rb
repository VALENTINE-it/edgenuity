class Mentor < ApplicationRecord
  has_many :mentoring_sessions, dependent: :destroy

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :role, presence: true, length: { minimum: 2, maximum: 100 }
  validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5.0 }, allow_nil: true

  after_commit :invalidate_cache

  def tags_array
    tags.to_s.split(",").map(&:strip).reject(&:empty?)
  end

  private

  def invalidate_cache
    Rails.cache.delete("public_mentors_collection")
    Rails.cache.delete("public_mentors_json")
  end
end
