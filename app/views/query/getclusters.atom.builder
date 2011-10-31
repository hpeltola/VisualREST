# Thison builds atomfeed
atom_feed do |feed|

  
  feed.title "Query clustered by: " + @clustered_by
  feed.updated Time.now
  
  @cluster_objects.each do |cluster_obj|
    url_for_cluster = "#{cluster_obj.get_uri}"
     feed.entry(cluster_obj, :id => url_for_cluster, :url => url_for_cluster) do |entry| 
      
      entry.title "Range: #{cluster_obj.get_range_string}"
      entry.description ""
      entry.icon_uri cluster_obj.get_icon_uri
      entry.query_uri @querystring_for_feed
      
      cluster_obj.get_content_objects.each do |content_obj|
        entry.file content_obj.get_uri(:atom)
      end
          
      thumbnail = '<img src="'  + cluster_obj.get_icon_uri + '" alt="icon" />'
      
      content = '<table><tr><td valign="top">' +
                 thumbnail + '</td><td valign="top">' +
                 "<b>Range (" + cluster_obj.get_cluster_by_type_for_range_string + "): " + cluster_obj.get_range_string.to_s + "</b><br/>" +
                 "<b>Clustered by: </b>" + cluster_obj.get_cluster_by_key.to_s + "</a><br/>" +
                 "<b>Max range: </b> " + cluster_obj.get_max_range.to_s + "<br/>" + 
                 "<b>Contains: </b> " + cluster_obj.get_size.to_s + " files<br/>"
                    
      
      entry.content content, :type => 'html'
      
      entry.author do |author|
        author.name("author name")
      end      
    end
  end
end