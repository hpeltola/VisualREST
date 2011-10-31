class CreateFileuploads < ActiveRecord::Migration
  def self.up
    create_table :fileuploads do |t|
      t.integer :devfile_id
      t.datetime :begin_time
      t.datetime :end_time

      t.timestamps
    end
  end

  def self.down
    drop_table :fileuploads
  end
end
