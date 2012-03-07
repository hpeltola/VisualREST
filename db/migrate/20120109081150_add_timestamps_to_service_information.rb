class AddTimestampsToServiceInformation < ActiveRecord::Migration
  def self.up
    add_column :service_informations, :created_at, :datetime
    add_column :service_informations, :updated_at, :datetime
    drop_table :flickrs    
  end

  def self.down
    remove_column :service_informations, :created_at
    remove_column :service_informations, :updated_at
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
end
