class CreateBlobs < ActiveRecord::Migration
  def self.up
    create_table :blobs do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :blobs
  end
end
