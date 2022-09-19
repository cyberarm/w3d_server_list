class TestSessions < ActiveRecord::Migration[7.0]
  def change
    create_table :test_sessions do |t|
      t.integer :event_id, required: true, unique: true

      t.string   :title, required: true
      t.datetime :start_time, required: true

      t.timestamps
    end
  end
end
