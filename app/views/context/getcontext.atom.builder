# Thison builds atomfeed
atom_feed do |feed|

  view_processing_time_begin = Time.now

  feed.title "Get context"
  feed.updated @context.updated_at
  
    feed.entry(@context, :id => "#{@host}/contexts/#{@context.context_hash}.atom", :url => "#{@host}/contexts/#{@context.context_hash}.atom") do |entry|
      
      @context_metadatas = @context_metadatas == nil ? [] : @context_metadatas
      

      entry.title @context_named_by_user
      entry.description @context.description
      entry.icon_uri @host + @context.icon_url
      entry.query_uri @host + @context.query_uri
      entry.private_context @context.private.to_s
      entry.context_hash @context.context_hash
      entry.context_owner @owner.username
      entry.context_owner_named @context.name
      
      m = ""
      
      entry.members do|members|
        m << "Members: <ul>"
        if @members.size != 0
          @members.each do |memb|
            members.member memb.username
            m << "<li> #{memb.username} </li>"
          end
        end
        m << "</ul>"
      end
      
      entry.context_xmpp_node @context.node_path
      entry.context_xmpp_node_service @context.node_service
      
      entry.rank_value @context.rank

      c = ""
      tags = ""
      country = nil
      place = nil
      lat = nil
      lon = nil
      entry.metadatas do |metadatas|
        if @context_metadatas.size != 0
          c << "Metadatas: <ul>"        
          @context_metadatas.each do |md|
            metadatas.meta :type => md.type_name, :value => md.value
            if md.type_name == "context_location_country" and md.value != nil and md.value != ""
              country = md.value
            elsif md.type_name == "context_location_name" and md.value != nil and md.value != ""
              place = md.value
            elsif md.type_name == "context_location_lat" and md.value != nil and md.value != ""
              lat = md.value
            elsif md.type_name == "context_location_lon" and md.value != nil and md.value != ""
              lon = md.value
            elsif md.type_name == "tag"
              tags += "#{md.value} "
            end
            c << "<li>" << "type_name: #{md.type_name}  value: #{md.value}" << "</li>"
            
          end
          c << "</ul>"
          c.gsub!("%2F", "/")
        end
      end
      
      
      entry.location do |location|
        if country
          location.country country
        end
        if place
          location.place place
        end
        if lat
          location.latitude lat 
        end
        if lon
          location.longitude lon 
        end
      end
      
      
      entry.begin_time @context.begin_time.to_s
      entry.end_time @context.end_time.to_s
      
      thumbnail = '<img src="'  + @context.icon_url + '" alt="icon" />'
      
      content = '<table><tr><td valign="top">' +
                 thumbnail + '</td><td valign="top">' +
                 "<b>Context name:</b> " + @context_named_by_user + "<br/>" +
                 "<b>Query uri:</b><a href="+@host+@context.query_uri+">" + @host+@context.query_uri + "</a><br/>" +
                 "<b>Private context:</b> " + @context.private.to_s + "<br/>"
                    
      if not @context.description.empty?
        content += @context.description
      end      
      if place
        content += "<b>Place:</b> " + place + "<br/>"
      end
      if country
        content += "<b>Country:</b> " + country + "<br/>" 
      end
      if tags != ""
        content += "<b>Tags:</b> " + tags.to_s + "<br/>"
      end
      
      content += "</td></tr></table>" + "<br/>"
      content += m
      content += c
      entry.content content, :type => 'html'
      
      entry.author do |author|
        author.name("author name")
      end

      entry.query_processing_time @query_processing_time
      view_processing_time_end = Time.now
      view_processing_time = view_processing_time_end - view_processing_time_begin
      entry.view_processing_time view_processing_time
      if @query_processing_time != nil and view_processing_time != nil
        processing_time = @query_processing_time + view_processing_time
        entry.processing_time processing_time      
      end
    end


end