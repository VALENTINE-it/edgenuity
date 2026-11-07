class User < ApplicationRecord
  has_secure_password

  has_many :mentoring_sessions, dependent: :destroy
  has_one :cookie_preference, dependent: :destroy

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    length: { maximum: 255 },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :role, inclusion: { in: %w[student mentor admin] }

  before_validation :normalize_credentials

  def first_name
    name.to_s.split.first || "Student"
  end

  def initials
    parts = name.to_s.split
    return "U" if parts.empty?
    parts.first(2).map { |p| p[0].upcase }.join
  end

  private

  def normalize_credentials
    self.name = name.to_s.strip if name.present?
    self.email = email.to_s.strip.downcase if email.present?
  end
end
