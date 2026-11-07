# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_11_07_100002) do
  create_table "admins", force: :cascade do |t|
    t.string "username", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "admin", null: false
    t.datetime "last_login_at"
    t.string "last_login_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["username"], name: "index_admins_on_username", unique: true
  end

  create_table "contact_messages", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "subject", null: false
    t.text "message", null: false
    t.string "status", default: "unread", null: false
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_contact_messages_on_created_at"
    t.index ["status"], name: "index_contact_messages_on_status"
  end

  create_table "cookie_preferences", force: :cascade do |t|
    t.integer "user_id"
    t.string "visitor_token", null: false
    t.string "consent_status", null: false
    t.boolean "essential", default: true, null: false
    t.boolean "functional", default: false, null: false
    t.boolean "analytics", default: false, null: false
    t.boolean "personalization", default: false, null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "consented_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["consent_status"], name: "index_cookie_preferences_on_consent_status"
    t.index ["user_id"], name: "index_cookie_preferences_on_user_id"
    t.index ["visitor_token"], name: "index_cookie_preferences_on_visitor_token"
  end

  create_table "mentoring_sessions", force: :cascade do |t|
    t.string "student_name"
    t.integer "mentor_id", null: false
    t.string "subject"
    t.string "topic"
    t.date "session_date"
    t.string "start_time"
    t.string "end_time"
    t.string "status"
    t.string "help_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["mentor_id"], name: "index_mentoring_sessions_on_mentor_id"
    t.index ["session_date"], name: "index_mentoring_sessions_on_session_date"
    t.index ["status"], name: "index_mentoring_sessions_on_status"
    t.index ["student_name"], name: "index_mentoring_sessions_on_student_name"
    t.index ["user_id"], name: "index_mentoring_sessions_on_user_id"
  end

  create_table "mentors", force: :cascade do |t|
    t.string "name"
    t.string "role"
    t.string "image"
    t.decimal "rating"
    t.string "sessions_count"
    t.string "tags"
    t.string "color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_mentors_on_name"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "student", null: false
    t.string "avatar_url"
    t.string "grade_level"
    t.datetime "last_login_at"
    t.string "last_login_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "cookie_preferences", "users"
  add_foreign_key "mentoring_sessions", "mentors"
  add_foreign_key "mentoring_sessions", "users"
end
