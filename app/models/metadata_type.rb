class MetadataType < ActiveRecord::Base
    has_many :metadatas
    has_many :context_metadatas
    
=begin    validates_uniqueness_of :name,
                            :on      => :create,
                            :message => "metadatatype already exists"
   
    validates_format_of :name, 
                        :with => /\w{1,20}/, 
                        :message => "must contain only letters, numbers and underscores"
=end    
end
