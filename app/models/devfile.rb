# Object of this class is used to describe metadata of a certain file in a certain device. Devfile has
# information about file's name, size, path, description, filetype, datetime when the file was 
# created and updated, about the file's privacy, is the file uploaded to server and if the devfile
# has thumbnail, object has thumbnailname. Devfile has also unique id and owner device's id.
#
#   Devfile belongs to device.
#   Has one fileupload.
#   Has many devfile_auth_users and devfile_auth_groups.
#   Through devfile_auth_users has many users.
#   Through devfile_auth_groups has many groups. (So file can be authorized through groups).
#
class Devfile < ActiveRecord::Base
  belongs_to :device
  
  has_many :blobs
  
  has_many :fileuploads
  has_one :filelocation

  has_many :devfile_auth_users
  has_many :devfile_auth_groups
  
  has_many :users, :through => :devfile_auth_users
  has_many :groups, :through => :devfile_auth_groups
  
  has_many :metadatas

  has_many :file_observers

end
