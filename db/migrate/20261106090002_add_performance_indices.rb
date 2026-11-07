class AddPerformanceIndices < ActiveRecord::Migration[7.2]
  def change
    add_index :mentoring_sessions, :student_name
    add_index :mentoring_sessions, :session_date
    add_index :mentoring_sessions, :status
    add_index :mentors, :name
  end
end
