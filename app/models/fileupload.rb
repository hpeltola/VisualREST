# Object of this class is used to keep track of file uploads. When file is started to upload, 
# the starting time is added to this object. When uploading is finished ending time is added to the object.
#
#   Belongs to on certain devfile.
class Fileupload < ActiveRecord::Base
  belongs_to :blob
end
