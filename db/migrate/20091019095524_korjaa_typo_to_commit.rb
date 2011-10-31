class KorjaaTypoToCommit < ActiveRecord::Migration
  def self.up
    remove_column :commits, :predecessot_commit_id
    add_column :commits, :previous_commit_id, :integer
  end

  def self.down
  end
end
