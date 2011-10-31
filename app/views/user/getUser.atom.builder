# Thison builds atomfeed
atom_feed do |feed|

  view_processing_time_begin = Time.now

  feed.title "User info"

  feed.updated @user.updated_at

  thumb_url = @host+'/user/'+@user.username+'/metadatas/thumbnail'

  feed.entry(@user, :id => @host+'/user/'+@user.username, :url=>@host+'/user/'+@user.username) do |entry|
    entry.title @user.real_name
    entry.name @user.real_name
    entry.username @user.username
    entry.thumbnail thumb_url

    content = '<table><tr><td valign="top">' +
              '<img src="'  + thumb_url + '" alt="' + @user.real_name + '" />' + '</td>' +
              '<td valign="top">' +
              "<b>Name:</b> " + @user.real_name + "<br/>" +
              "<b>Username:</b> " + @user.username + "<br/>" +
              "</td></tr></table>"

    if @own_groups != nil
      entry.own_groups do |own_groups|
        @own_groups.each do |x|
          content += '<table><tr><b>Own Group:</b></tr>' + 
                     '<tr>&nbsp; Name: ' + x["name"] + '</tr>' +
                     '<tr>&nbsp; Members: ' + x["members"].to_s + '</tr></table>'
          own_groups.group :name => x["name"], :members => x["members"]
        end
      end
    end

    
    if @groups != nil
      entry.groups do |groups|
        @groups.each do |x|
          content += '<table><tr><b>Member in Group:</b></tr>' + 
                     '<tr>&nbsp; Name: ' + x["name"] + '</tr>' +
                     '<tr>&nbsp; Owner: ' + x["owner_name"] + '</tr>' + 
                     '<tr>&nbsp; Members: ' + x["members"].to_s + '</tr></table>'
          groups.group :name => x["name"], :owner => x["owner_name"], :members => x["members"]
        end
      end
    end
    
    if @friends != nil
      entry.users_in_same_group_with_you do |users_in_same_group_with_you|
        content += '<br /><table><tr><b>Users in same group with you:</b></tr>'
        @friends.each do |i, friend|
          content += '<tr>&nbsp; ' + friend + '</tr>'
          users_in_same_group_with_you.user :username => friend
        end
        content += '</table>'
      end
    end
  
                       
    entry.content content, :type => 'html'

    entry.author do |author|
        author.name(@user)
    end

    entry.query_processing_time @query_processing_time
    view_processing_time_end = Time.now
    view_processing_time = view_processing_time_end - view_processing_time_begin
    entry.view_processing_time view_processing_time
    processing_time = @query_processing_time + view_processing_time
    entry.processing_time processing_time
      
  end


end