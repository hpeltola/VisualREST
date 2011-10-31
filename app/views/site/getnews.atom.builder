# Thison builds atomfeed
atom_feed do |feed|
  title = "News from VisualREST"
  feed.title title

  id = 0
  user = ""
  dev = ""
  newest_datetime = nil
  
  feed.updated if not @news.empty? ? @news[0].created_at : Time.now


  @news.each do |n|
    feed.entry(n, :id => @host+"/news/"+n.id.to_s, :url=>@host+"/news/"+n.id.to_s) do |entry|
      entry.title n.created_at
      entry.description n.description
      entry.username n.user.username
            
      
      entry.content '<table><tr><td valign="top">' +
      n.created_at.strftime("%d/%m") +'<br/>' + n.user.username + '</td><td valign="top">' +
      "<b>description</b>: #{n.description}<br/>", :type => 'html'
  
      entry.author do |author|
        author.name(@user)
      end      
    end
  end

  
end
