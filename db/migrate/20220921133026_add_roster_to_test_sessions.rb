class AddRosterToTestSessions < ActiveRecord::Migration[7.0]
  def change
    add_column :test_sessions, :testing_roster, :text, default: ""
  end
end
