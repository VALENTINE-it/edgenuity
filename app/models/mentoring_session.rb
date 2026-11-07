class MentoringSession < ApplicationRecord
  belongs_to :mentor
  belongs_to :user, optional: true

  validates :student_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :subject, presence: true
  validates :session_date, presence: true
  validates :start_time, presence: true
  validates :status, inclusion: { in: %w[pending confirmed completed cancelled] }

  scope :upcoming, -> { where("session_date >= ?", Date.today).order(session_date: :asc) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_student, ->(name) { where(student_name: name) }
end
