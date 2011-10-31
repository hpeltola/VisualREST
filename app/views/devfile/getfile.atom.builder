# Thison builds atomfeed
atom_feed do |feed|
  title = "Content Metadatas"
  
  feed.title title

  id = 0
  user = ""
  dev = ""
  newest_datetime = nil
  
  view_processing_time_begin = Time.now
  
  @results.each do |file|
    if id == 0 then newest_datetime = file.updated_at
    elsif newest_datetime < file.updated_at then newest_datetime = file.updated_at end
  end

  feed.updated newest_datetime


  @results.each do |file|
    if file.device_id != id
      id = file.device_id
      @user = file.username
      @dev = file.dev_name
    end
 #   tmp = @host + devfile_url(file).gsub!("%2F", "/")
    feed.entry(file, :id => @host+devfile_url(file), :url=>@host+devfile_url(file)) do |entry|
      entry.title file.name
      if file.thumbnail_name != nil 
        thumburl = "/thumbnails/" + file.device_id.to_s + "/" + file.thumbnail_name
        thumbnail = '<img src="'  + thumburl + '" alt="' + file.name + '" />'
        entry.thumbnail @host+thumburl
      else 
        thumbnail = '<img src="/thumbnails/vR_no_picture_2.png" alt="Thumbnail not found!" />'
      end
      
      versionlisturl = versionlist_url(file)

 #     if file.description != nil
        entry.description file.description
#      end
      
      entry.file_version file.version
      entry.filepath file.path
      entry.filetype file.filetype
      entry.filesize file.size.to_s
      entry.rank_value file.rank
      entry.file_device @dev
      entry.file_versionlist_url @host+versionlisturl
      entry.version_hash file.blob_hash
      
      
      meta = @metadatas[file.devfile_id.to_i]
      if meta != nil
        meta.each do |key, value|
        
          entry.meta :type => key, :value => value
        end
        
      end
      
      if file.longitude != nil and file.latitude != nil
        entry.location do |location|
          location.longitude file.longitude
          location.latitude file.latitude
        end
      end
      
      
      t = Time.parse(file.last_seen)
      # Checks that if file is cached
      if file.uploaded.to_s == "1" or file.uploaded.to_s == "true"
        entry.file_status "cached"
      else
        entry.file_status "not cached"
      end
      
      if t > 2.minutes.ago
        entry.device_status "online"
      else
        entry.device_status "offline"
      end
      
      
      entry.content '<table><tr><td valign="top">' +
      thumbnail + '</td><td valign="top">' +
      "<b>" + (file.path + file.name)[1..-1] + "</b> - version: #{file.version}<br/>" +
      "type: " + file.filetype + "<br/>" +
      "size: " + file.size.to_s() + " B<br/>" +
      "<b>Device:</b> " + @dev + "<br/>" +
      "<b>User:</b> " + @user + "<br/>" +
      "<a href=\"#{versionlisturl}\">Version list</a>" +
      "</td></tr></table>", :type => 'html'

#      entry.content "<table>" + 
#      "<tr>" + '<td rowspan="6">' + thumbnail + "</td>" +
#      "<td><b>" + (file.path + file.name)[1..-1] + "</b> - version: #{file.version}<br/></td></tr>" +
#      "<tr><td>" + "type: " + file.filetype + "</td></tr>" +
#      "<tr><td>" + "size: " + file.size.to_s() + " B<br/>" + "</td></tr>" +
#      "<tr><td>" + "<b>Device:</b> " + @dev + "<br/>" + "</td></tr>" +
#      "<tr><td>" + "<b>User:</b> " + @user + "<br/>" +  "</td></tr>" +
#      "<tr><td>" + '<a href="' + devfile_url(file) + '?versions=all&format=atom">Version list</a></td></tr>' +
#      "</table>", :type => 'html'


      #feed.query_processing_time @query_processing_time
      #view_processing_time_end = Time.now
      #view_processing_time = view_processing_time_end - view_processing_time_begin
      #entry.view_processing_time view_processing_time
      
      #processing_time = @query_processing_time + view_processing_tim
      #entry.processing_time processing_time
  
      entry.author do |author|
        author.name(@user)
      end      
    end
  end

  
end
