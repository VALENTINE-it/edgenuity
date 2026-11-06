class CreateMentoringSessions < ActiveRecord::Migration[7.2]
  def change
    create_table :mentoring_sessions do |t|
      t.string :student_name
      t.references :mentor, null: false, foreign_key: true
      t.string :subject
      t.string :topic
      t.date :session_date
      t.string :start_time
      t.string :end_time
      t.string :status
      t.string :help_type

      t.timestamps
    end
  end
end
