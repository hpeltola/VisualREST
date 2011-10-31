class Metadata < ActiveRecord::Base
      belongs_to :blob
      belongs_to :devfile
      belongs_to :metadata_type
      
      
      #validates_uniqueness_of :metadata_type_id, :scope => "devfile_id", :on => :create
=begin     
      metadata = {}
      
      def addMetadata(mdata)
        metadata = mdata
      end
      
      def getMetadata
        return metadata
      end
=end     
end
