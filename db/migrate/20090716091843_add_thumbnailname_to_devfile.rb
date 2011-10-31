class AddThumbnailnameToDevfile < ActiveRecord::Migration
  def self.up
    add_column :devfiles, :thumbnail_name, :string
  end

  def self.down
    remove_column :devfiles, :thumbnail_name
  end
end
