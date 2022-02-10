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

ActiveRecord::Schema[7.0].define(version: 2022_02_10_130415) do
  create_table "reports", force: :cascade do |t|
    t.integer "server_id"
    t.string "map_name"
    t.integer "player_count"
    t.datetime "started_at"
    t.string "remaining"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "servers", force: :cascade do |t|
    t.string "uid"
    t.string "hostname"
    t.string "game"
    t.string "address"
    t.integer "port"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
