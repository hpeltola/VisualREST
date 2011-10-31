class CreateBlobsInCommits < ActiveRecord::Migration
  def self.up
    create_table :blobs_in_commits do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :blobs_in_commits
  end
end
