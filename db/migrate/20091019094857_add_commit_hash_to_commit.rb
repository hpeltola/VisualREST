class AddCommitHashToCommit < ActiveRecord::Migration
  def self.up
    add_column :commits, :commit_hash, :string
  end

  def self.down
    remove_column :commits, :commit_hash
  end
end
