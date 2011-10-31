class AddRootDirIdToUserDropboxContent < ActiveRecord::Migration
  def self.up
    add_column :user_dropbox_contents, :root_dir_id, :integer
  end

  def self.down
    remove_column :user_dropbox_contents, :root_dir_id
  end
end
