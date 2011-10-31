# Object of this class is used to define which groups has access to certain files.
# Object has information about when it was created and updated. Has ids of the devfile and the device.
#
#   Belongs to one group and one devfile.
#
class DevfileAuthGroup < ActiveRecord::Base
  belongs_to :group
  belongs_to :devfile
end
