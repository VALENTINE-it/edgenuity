class CookiePreference < ApplicationRecord
  belongs_to :user, optional: true

  validates :visitor_token, presence: true
  validates :consent_status, inclusion: { in: %w[accepted denied custom] }
  validates :consented_at, presence: true

  scope :accepted, -> { where(consent_status: "accepted") }
  scope :denied, -> { where(consent_status: "denied") }

  def functional_allowed?
    essential? && functional?
  end

  def analytics_allowed?
    essential? && analytics?
  end

  def personalization_allowed?
    essential? && personalization?
  end
end
