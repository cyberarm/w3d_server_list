class CreateServers < ActiveRecord::Migration[7.0]
  def change
    create_table :servers do |t|
      t.string  :uid, required: true
      t.string  :hostname, required: true
      t.string  :game, required: true
      t.string  :address, required: true
      t.integer :port, required: true

      t.timestamps
    end
  end
end
