
atom_feed do |feed|

  view_processing_time_begin = Time.now

  feed.title "Group: " + @group.name

  feed.updated @group.updated_at


  feed.entry(@group, :id => @host+'/user/'+@owner.username+'/group/'+@group.name, :url=>@host+'/user/'+@owner.username+'/group/'+@group.name) do |entry|
    entry.title @group.name
    entry.owner @owner.username

    content = '<table><tr>' +
              '<td valign="top">' +
              "<b>Group name:</b> " + @group.name + "<br/>" +
              "<b>Owner:</b> " + @owner.username + "<br/>" +
              "</td></tr></table>"

    if @members != nil
      entry.members do |members|
        @members.each do |x|
          content += '<table><tr><b>Members:</b></tr>' + 
                     '<tr>&nbsp; Name: ' + x["username"] + '</tr>' +
                     '</table>'
          members.member :name => x["username"]
        end
      end
    end

    
    if @devices != nil
      entry.devices do |devices|
        @devices.each do |x|
          content += '<table><tr><b>Authorized for devices:</b></tr>' + 
                     '<tr>&nbsp; User: ' + x["username"] + '</tr>' +
                     '<tr>&nbsp; Device: ' + x["dev_name"] + '</tr>' + 
                     '</table>'
          devices.device :user => x["username"], :device => x["dev_name"]
        end
      end
    end
    
    if @files != nil
      entry.files do |files|
        @files.each do |x|
          content += '<table><tr><b>Authorized for files:</b></tr>' + 
                     '<tr>&nbsp; User: ' + x["username"] + '</tr>' +
                     '<tr>&nbsp; Device: ' + x["dev_name"] + '</tr>' + 
                     '<tr>&nbsp; Name: ' + x["path"] + x["name"] + '</tr>' + 
                     '</table>'
          files.file :user => x["username"], :device => x["dev_name"], :name => x["path"]+x["name"]
        end
      end
    end
  
                       
    entry.content content, :type => 'html'

    entry.author do |author|
        author.name(@owner.username)
    end

    entry.query_processing_time @query_processing_time
    view_processing_time_end = Time.now
    view_processing_time = view_processing_time_end - view_processing_time_begin
    entry.view_processing_time view_processing_time
    processing_time = @query_processing_time + view_processing_time
    entry.processing_time processing_time
      
  end


end