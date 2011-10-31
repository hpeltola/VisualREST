# List of metadata types that already exists. These types can't be created
@@existing_metadata_types = ["id", "name", "path", "description", "filetype", "type", "uploaded", "latitude",
                             "longitude", "filedate", "file_status", "created_at", "updated_at",
                             "privatefile", "size", "upload_requested", "thumbnail_name", "version",
                             "blob_hash", "localhost_context_polling", "rank" ]


@@unremovable_context_metadata = ["context_location_lat", "context_location_lon",
                                  "context_location_country", "context_location_name"]


@@uninclude_from_context_query = ["context_location_lat", "context_location_lon",
                                  "context_location_country", "context_location_name"]


@@multi_metadata_types_for_context = ["tag"]

# Context has right to modify these metadatas for devfile 
# DEFINES that to which context the devile belongs to
@@devfile_context_metadata = {"tag" => "string",
                              "context_location_lon" => "float",
                              "context_location_lat" => "float",
                              "context_location_name" => "string",
                              "context_location_country" => "string",
                              "context_hash" => "string",
                              "context_name" => "string",
                              "backup_uri" => "string",
                              "backup_time" => "string",
                              "backup_recovery_path" => "string",
                              "mail_topic" => "string",
                              "mail_from" => "string", 
                              "taken" => "datetime",
                              "url" => "string",
                              "origin" => "string"}
     
begin
  # Go through the list of metadatatypes listed above and add missing metadatatypes                                 
  @@devfile_context_metadata.each do |key, valuetype|
    mdtype = MetadataType.find_by_name(key)
    if not mdtype
      MetadataType.create(:name => key, :value_type => valuetype)
      puts "Created metadatatype: #{key}, valuetype: #{valuetype}" 
    end
    
  end
rescue Exception => e
  puts "Error: #{e.to_s}"
  puts "  -- line: #{e.backtrace[0].to_s}"
end