class CreateNodes < ActiveRecord::Migration
  def self.up
    create_table :nodes do |t|
      t.string :node_name
      t.string :node_service
      t.integer :user_id

      #t.timestamps
    end
  end

  def self.down
    drop_table :nodes
  end
end
