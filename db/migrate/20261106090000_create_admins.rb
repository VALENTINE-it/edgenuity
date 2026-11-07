class CreateAdmins < ActiveRecord::Migration[7.2]
  def change
    create_table :admins do |t|
      t.string :username, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, default: "admin", null: false
      t.datetime :last_login_at
      t.string :last_login_ip

      t.timestamps
    end

    add_index :admins, :username, unique: true
    add_index :admins, :email, unique: true
  end
end
