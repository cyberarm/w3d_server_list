class AddMaxPlayersToReports < ActiveRecord::Migration[7.0]
  def change
    add_column :reports, :max_players, :integer, default: 0
  end
end
