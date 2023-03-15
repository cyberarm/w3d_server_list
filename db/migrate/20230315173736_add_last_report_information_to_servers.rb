class AddLastReportInformationToServers < ActiveRecord::Migration[7.0]
  def change
    add_column :servers, :map_name, :string, default: ""
    add_column :servers, :player_count, :integer, default: 0
    add_column :servers, :max_players, :integer, default: 0
  end
end
