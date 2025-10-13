class CreateSolidCableTables < ActiveRecord::Migration[8.0]
  def change
    create_table :solid_cable_messages do |t|
      t.binary :channel, null: false, limit: 1024
      t.binary :payload, null: false, limit: 536870912
      t.datetime :created_at, null: false
      t.bigint :channel_hash, null: false
      
      t.index :channel_hash
      t.index [:channel, :created_at], length: { channel: 255 }
    end
  end
end
