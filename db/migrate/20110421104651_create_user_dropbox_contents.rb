class CreateUserDropboxContents < ActiveRecord::Migration
  def self.up
    create_table :user_dropbox_contents do |t|

      t.integer :user_id
      t.string :content_type
      t.string :path
      t.string :content_hash
      t.integer :parent_dir_id
      
      t.integer :device_id
      

      t.timestamps
    end
  end

  def self.down
    drop_table :user_dropbox_contents
  end
end
