class AddToContextCreatedAtUpdatedAt < ActiveRecord::Migration
  def self.up
    add_column :contexts, :created_at, :datetime
    add_column :contexts, :updated_at, :datetime
  end

  def self.down
    remove_column :contexts, :created_at
    remove_column :contexts, :updated_at
  end
end
