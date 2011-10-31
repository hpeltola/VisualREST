class CreateFlickrs < ActiveRecord::Migration
  def self.up
    create_table :flickrs do |t|
      t.integer :user_id
      t.string :flickr_username
      t.string :flickr_nsid
      t.string :flickr_token
      t.datetime :public_last_time
      t.datetime :private_last_time

      t.timestamps
    end
  end

  def self.down
    drop_table :flickrs
  end
end
