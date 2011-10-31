class AddColumnsToBranch < ActiveRecord::Migration
  def self.up
    add_column :branches, :parent_blob_id, :integer
    add_column :branches, :child_blob_id, :integer
  end

  def self.down
    remove_column :branches, :child_blob_id
    remove_column :branches, :parent_blob_id
  end
end
