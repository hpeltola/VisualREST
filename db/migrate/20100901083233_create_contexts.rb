class CreateContexts < ActiveRecord::Migration
  def self.up
    create_table :contexts do |t|
      
      t.integer :user_id
      t.string :query_uri
      
      t.string :name
      t.string :icon_url
      t.string :description
      t.string :location_country
      t.string :location_name
      t.float  :location_lat
      t.float  :location_lon
      t.datetime :begin_time
      t.datetime :end_time
      
      t.string  :email

      #t.timestamps
    end
  end

  def self.down
    drop_table :contexts
  end
end
