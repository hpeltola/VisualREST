class AddTimestamps < ActiveRecord::Migration
  def self.up
    add_column :context_metadatas, :created_at, :datetime
    add_column :context_metadatas, :updated_at, :datetime
    add_column :users, :created_at, :datetime
    add_column :users, :updated_at, :datetime
  end

  def self.down
    remove_column :context_metadatas, :created_at
    remove_column :context_metadatas, :updated_at
    remove_column :users, :created_at
    remove_column :users, :updated_at
  end
end
