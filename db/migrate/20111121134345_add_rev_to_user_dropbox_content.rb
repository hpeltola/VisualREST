class AddRevToUserDropboxContent < ActiveRecord::Migration
  def self.up
    add_column :user_dropbox_contents, :rev, :string
  end

  def self.down
    remove_column :user_dropbox_contents, :rev
  end
end
