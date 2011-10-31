# No inmplementation currently.
class DevfileAuthUser < ActiveRecord::Base
  belongs_to :user
  belongs_to :devfile

end
