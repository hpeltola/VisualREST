class AddIndexBlobsInCommitsCommitIdBlobIdIndex < ActiveRecord::Migration
  def self.up
    add_index(:blobs_in_commits, [:commit_id, :blob_id], :unique => true)
  end

  def self.down
    remove_index :blobs_in_commits, :column => [:commit_id, :blob_id]
  end
end
