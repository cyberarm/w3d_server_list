class AddCreatedAtIndexToReports < ActiveRecord::Migration[7.0]
  def change
    add_index :reports, [:server_id, :created_at]
  end
end
