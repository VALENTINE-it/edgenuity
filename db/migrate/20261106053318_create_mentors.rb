class CreateMentors < ActiveRecord::Migration[7.2]
  def change
    create_table :mentors do |t|
      t.string :name
      t.string :role
      t.string :image
      t.decimal :rating
      t.string :sessions_count
      t.string :tags
      t.string :color

      t.timestamps
    end
  end
end
