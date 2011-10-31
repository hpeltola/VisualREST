# Object of this class is used to define the location data of a certain devfile
#
#   Belongs to on certain devfile.
class Filelocation < ActiveRecord::Base
  belongs_to :devfile
end
