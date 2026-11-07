class CreateCookiePreferences < ActiveRecord::Migration[7.2]
  def change
    create_table :cookie_preferences do |t|
      t.references :user, foreign_key: true, null: true
      t.string :visitor_token, null: false
      t.string :consent_status, null: false # "accepted", "denied", "custom"
      t.boolean :essential, default: true, null: false
      t.boolean :functional, default: false, null: false
      t.boolean :analytics, default: false, null: false
      t.boolean :personalization, default: false, null: false
      t.string :ip_address
      t.string :user_agent
      t.datetime :consented_at, null: false

      t.timestamps
    end

    add_index :cookie_preferences, :visitor_token
    add_index :cookie_preferences, :consent_status
  end
end
