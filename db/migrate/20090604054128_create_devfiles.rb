class CreateDevfiles < ActiveRecord::Migration
  def self.up
    create_table :devfiles do |t|
      t.integer :device_id
      t.string :name
      t.integer :size
      t.string :path
      t.string :description
      t.string :filetype

      t.timestamps
    end
  end

  def self.down
    drop_table :devfiles
  end
end
