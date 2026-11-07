class CreateContactMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :contact_messages do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :subject, null: false
      t.text :message, null: false
      t.string :status, default: "unread", null: false
      t.string :ip_address

      t.timestamps
    end

    add_index :contact_messages, :status
    add_index :contact_messages, :created_at
  end
end
