# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of ActiveRecord to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20090604054128) do

  create_table "devfiles", :force => true do |t|
    t.integer  "device_id"
    t.string   "name"
    t.integer  "size"
    t.string   "path"
    t.string   "description"
    t.string   "filetype"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "devices", :force => true do |t|
    t.integer  "user_id"
    t.string   "id_digest"
    t.string   "dev_name"
    t.string   "dev_type"
    t.datetime "last_seen"
    t.boolean  "direct_access"
    t.string   "address"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "groups", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", :force => true do |t|
    t.string "real_name"
    t.string "username"
    t.string "password"
  end

  create_table "usersingroups", :id => false, :force => true do |t|
    t.integer  "user_id"
    t.integer  "group_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
