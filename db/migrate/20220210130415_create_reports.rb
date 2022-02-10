class CreateReports < ActiveRecord::Migration[7.0]
  def change
    create_table :reports do |t|
      t.integer :server_id, required: true

      t.string   :map_name, required: true
      t.integer  :player_count, required: true
      t.datetime :started_at, required: true
      t.string   :remaining, required: true

      t.timestamps
    end
  end
end
