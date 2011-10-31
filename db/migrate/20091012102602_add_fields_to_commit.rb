class AddFieldsToCommit < ActiveRecord::Migration
  def self.up
    add_column :commits, :predecessot_commit_id, :string
  end

  def self.down
    remove_column :commits, :predecessot_commit_id
  end
end
