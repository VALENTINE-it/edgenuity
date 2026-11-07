class Admin < ApplicationRecord
  has_secure_password

  validates :username, presence: true,
                       uniqueness: { case_sensitive: false },
                       length: { minimum: 3, maximum: 50 },
                       format: { with: /\A[a-zA-Z0-9_\-\.]+\z/, message: "only allows letters, numbers, dots, hyphens, and underscores" }

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    length: { maximum: 255 },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :role, inclusion: { in: %w[admin superadmin] }

  before_validation :normalize_attributes

  private

  def normalize_attributes
    self.username = username.to_s.strip.downcase if username.present?
    self.email = email.to_s.strip.downcase if email.present?
  end
end
