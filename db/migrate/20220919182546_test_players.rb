class TestPlayers < ActiveRecord::Migration[7.0]
  def change
    create_table :test_players do |t|
      t.integer :test_session_id, required: true

      t.string   :nickname, required: true
      t.string   :server_game, required: true
      t.string   :server_name, required: true
      t.string   :server_address, required: true
      t.datetime :join_time, required: true
      t.datetime :leave_time, required: true
      t.integer  :duration, required: true

      t.timestamps
    end
  end
end
