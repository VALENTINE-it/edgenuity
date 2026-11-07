class AddUserIdToMentoringSessions < ActiveRecord::Migration[7.2]
  def change
    add_reference :mentoring_sessions, :user, foreign_key: true, null: true
  end
end
