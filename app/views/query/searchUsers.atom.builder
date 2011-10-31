# Thison builds atomfeed
atom_feed do |feed|

  view_processing_time_begin = Time.now

  feed.title "User search results"
  feed.updated Time.now.utc

  if @users != nil
    @users.each do |user|
	
	  url = "#{@host}/user/#{user.username}.atom"

      feed.entry(user, :id => @request_url, :url => url) do |entry|
        @content = "Username: " + user.username.to_s() + "<br/>"
  #      @content << "Email: " << user.email.to_s() << "<br/>"
        
        entry.title user.real_name    
        entry.username user.username
        entry.thumbnail @host + "/user/" + user.username + "/metadatas/thumbnail"
        entry.updated user.updated_at.to_s #.xmlschema
   
        entry.content @content, :type=>"html"
        
        entry.content '<table><tr><td valign="top">' +
                '<img src="/user/' + user.username + '/metadatas/thumbnail" alt="Thumbnail not found!" />' + 
                '</td><td valign="top">' +                
                "<b>Name:</b> " + user.real_name + "<br/>" +
                "<b>Username:</b> " + user.username + "<br/>" +
                "</td></tr></table>", :type => 'html'
        
        
        entry.author do |author|
          author.name "admin"
        end
      
	    entry.query_processing_time @query_processing_time
	  
	    view_processing_time_end = Time.now
	    view_processing_time = view_processing_time_end - view_processing_time_begin
	    entry.view_processing_time view_processing_time
	  
	    processing_time = @query_processing_time + view_processing_time
	
	    entry.processing_time processing_time

      end
    end
  end
  



end