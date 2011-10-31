# No inmplementation currently.
class DeviceAuthGroup < ActiveRecord::Base
  belongs_to :device
  belongs_to :group
end
