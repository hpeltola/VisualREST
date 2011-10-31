class AddCommitIdToDevice < ActiveRecord::Migration
  def self.up
    add_column :devices, :commit_id, :integer
  end

  def self.down
    remove_column :devices, :commit_id
  end
end
