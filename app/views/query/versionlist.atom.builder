# Thison builds atomfeed
atom_feed do |feed|
  title = "Versions of " + @results.first.name + ", Device: " +
  @results.first.dev_name + ", User: " + @results.first.username
  feed.title title
  feed.subtitle title

  id = 0
  user = ""
  dev = ""
  newest_datetime = nil
  
  
  @results.each do |file|
    if id == 0 then newest_datetime = file.created_at
    elsif newest_datetime < file.created_at then newest_datetime = file.created_at end
    feed.entry(file, :id => file.id, :url=>blob_url(file).gsub!("%2F", "/"), :updated => file.created_at) do |entry|
      entry.title file.name
      if file.thumbnail_name != nil 
        thumburl = "/thumbnails/" + file.device_id.to_s + "/" + file.thumbnail_name
        thumbnail = '<img src="'  + thumburl + '" alt="' + file.name + '" />'
        entry.thumbnail thumburl
      else 
        thumbnail = '<img src="/thumbnails/vR_no_picture_2.png" alt="Thumbnail not found!" />'
      end

      entry.file_version file.version
      entry.filepath file.path
      entry.filetype file.filetype
      entry.filesize file.size.to_s
      entry.file_device file.dev_name
      entry.version_hash file.blob_hash
      if file.longitude != nil and file.latitude != nil
        entry.location do |location|
          location.longitude file.longitude
          location.latitude file.latitude
        end
      end
      
#      branch_information = ""
#      
#      if file.branch_details and !file.branch_details.empty?
#        
#        branch_information = "<b>This file has also versions from other users or devices:</b>
#        <table><tr><td>
#        
#        User #{file.branch_details['user_name']}, device #{file.branch_details['device_name']} has:
#        #{file.branch_details['blob'].blob_hash}
#        
#        </td></tr></table>"
#        
#        puts "B_det: " + file.branch_details['blob'].blob_hash
#        
#      end
      
      t = Time.parse(file.last_seen)
      # Checks that if file is cached
      if file.uploaded == true
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
      "<b>version: #{file.version}</b><br/>" +
      "type: " + file.filetype + "<br/>" +
      "size: " + file.size.to_s() + " B<br/>" +
      "</td></tr></table>", :type => 'html'

      entry.author do |author|
        author.name(@results.first.username)
      end
      
    end
  end
  
  feed.updated newest_datetime
end