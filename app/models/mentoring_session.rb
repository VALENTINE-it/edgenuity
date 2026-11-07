class MentoringSession < ApplicationRecord
  belongs_to :mentor

  validates :student_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :subject, presence: true
  validates :session_date, presence: true
  validates :start_time, presence: true
  validates :status, inclusion: { in: %w[pending confirmed completed cancelled] }

  scope :upcoming, -> { where("session_date >= ?", Date.today).order(session_date: :asc) }
  scope :for_student, ->(name) { where(student_name: name) }
end
