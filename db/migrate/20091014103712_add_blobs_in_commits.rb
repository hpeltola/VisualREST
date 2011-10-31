class AddBlobsInCommits < ActiveRecord::Migration
  def self.up
      drop_table :blobs_in_commits
      create_table :blobs_in_commits, :id => false do |t|
      t.integer :blob_id
      t.integer :commit_id

      t.timestamps
    end
  end

  def self.down
    drop_table :blobs_in_commits
  end
end
