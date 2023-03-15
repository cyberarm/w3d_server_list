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

ActiveRecord::Schema[7.0].define(version: 2023_03_15_190753) do
  create_table "reports", force: :cascade do |t|
    t.integer "server_id"
    t.string "map_name"
    t.integer "player_count"
    t.datetime "started_at"
    t.string "remaining"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "max_players", default: 0
    t.index ["server_id", "created_at"], name: "index_reports_on_server_id_and_created_at"
    t.index ["server_id"], name: "index_reports_on_server_id"
  end

  create_table "servers", force: :cascade do |t|
    t.string "uid"
    t.string "hostname"
    t.string "game"
    t.string "address"
    t.integer "port"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "map_name", default: ""
    t.integer "player_count", default: 0
    t.integer "max_players", default: 0
  end

  create_table "test_players", force: :cascade do |t|
    t.integer "test_session_id"
    t.string "nickname"
    t.string "server_game"
    t.string "server_name"
    t.string "server_address"
    t.datetime "join_time"
    t.datetime "leave_time"
    t.integer "duration"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "test_sessions", force: :cascade do |t|
    t.integer "event_id"
    t.string "title"
    t.datetime "start_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "testing_roster", default: ""
  end

end
