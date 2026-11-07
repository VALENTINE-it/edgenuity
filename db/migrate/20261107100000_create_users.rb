class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, default: "student", null: false
      t.string :avatar_url
      t.string :grade_level
      t.datetime :last_login_at
      t.string :last_login_ip

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :role
  end
end
