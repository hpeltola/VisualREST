# Object of this class is used to describe which user is member of which group. 
# Object has user's and group's ids.
#
#   Belongs to certain user and certain group.
#
class Usersingroup < ActiveRecord::Base
  belongs_to :user
  belongs_to :group
end
