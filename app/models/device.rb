# Object of this class is used to describe on acrual device. Object has informations about device's 
# name, type, when device was last time seen online, can device be reached through http and if so, 
# what is the address and port. Object has also devices Jabber account information (name and password).
# Device can be identified with hash (id_digest) or with id.
#
#   Belongs to one certain user.
#   Has many devfiles, device_auth_users and device_auth_groups.
#   Has many users through device_auth_users.
#   Has meny groups through device_auth_groups.
#
class Device < ActiveRecord::Base
  belongs_to :user
  has_many :devfiles

  has_many :device_auth_users
  has_many :device_auth_groups
  
  has_many :users, :through => :device_auth_users
  has_many :groups, :through => :device_auth_groups
  
  has_many :commits
  
  has_many :device_locations
end
