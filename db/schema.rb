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

ActiveRecord::Schema[7.2].define(version: 2026_11_06_053327) do
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
    t.index ["mentor_id"], name: "index_mentoring_sessions_on_mentor_id"
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
  end

  add_foreign_key "mentoring_sessions", "mentors"
end
