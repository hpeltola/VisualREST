class CreateContextNames < ActiveRecord::Migration
  def self.up
    create_table :context_names do |t|
      t.integer :context_id
      t.string :name
      t.string :context_hash
      t.integer :user_id
      t.string :username

      t.timestamps
    end
  end

  def self.down
    drop_table :context_names 
  end
end
