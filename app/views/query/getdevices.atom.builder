# Thison builds atomfeed
atom_feed do |feed|
  title = ""
  if not @context.empty?
    title += "Files of " + @context[:user].username
    if @context[:device] then title += ", Device: " + @context[:device].dev_name end
    if @querystring_for_feed != nil then title += ", " end
  end
  if @querystring_for_feed != nil then title += "Query: " + @querystring_for_feed end
  feed.title title
  feed.updated Time.now.utc
  
  @results.each do |device|
    feed.entry(device, :id => @host+link_to_files_of_device(device.id), :url => @host+link_to_files_of_device(device.id)) do |entry|
      @content = "Last seen: " + device.last_seen.to_s() + "<br/>"
      @content << "Device type: " << device.dev_type << "<br/>"
      
      @files = device.devfiles
      if @files.size != 0
        @content << "Files: <ul>"        
        @files.each do |file|
          @content << "<li>" << link_to_file_of_device(file.name, device.id, (file.path + file.name)[1..-1]) << "</li>"
        end
        @content << "</ul>"
        @content.gsub!("%2F", "/")
      end
      
      entry.title device.dev_name
      
      entry.device_type device.dev_type
      entry.last_seen device.last_seen.to_s
      
      entry.content @content, :type=>"html"
      
      entry.author do |author|
        author.name(device.username)
      end      
    end
  end
end