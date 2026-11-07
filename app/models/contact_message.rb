class ContactMessage < ApplicationRecord
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :email, presence: true, length: { maximum: 255 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :subject, presence: true, length: { minimum: 2, maximum: 150 }
  validates :message, presence: true, length: { minimum: 5, maximum: 5000 }
  validates :status, inclusion: { in: %w[unread read replied archived] }

  before_validation :sanitize_and_normalize

  scope :unread, -> { where(status: "unread") }
  scope :recent, -> { order(created_at: :desc) }

  private

  def sanitize_and_normalize
    self.name = name.to_s.strip if name.present?
    self.email = email.to_s.strip.downcase if email.present?
    self.subject = subject.to_s.strip if subject.present?
    self.message = message.to_s.strip if message.present?
  end
end
