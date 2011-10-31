class CreateFrontpageNews < ActiveRecord::Migration
  def self.up
    create_table :frontpage_news do |t|
      t.text :description
      t.integer :user_id

      t.timestamps
    end
  end

  def self.down
    drop_table :frontpage_news
  end
end
