# No inmplementation currently.
class DeviceAuthUser < ActiveRecord::Base
  belongs_to :user
  belongs_to :device
end
