# Thison builds atomfeed
atom_feed do |feed|
  title = "List of metadatavalues for type: #{@metadatatype.name}"
  feed.title title
  feed.updated Time.now.utc

  link = @host + "/files?q[" + @metadatatype.name + "]="
  
  @results.each do |value, amount|
    feed.entry(value, :id => link+value, :url => link+value) do |entry|
      entry.title value
      entry.value value
      entry.amount amount

      
      entry.content "<p>Value: #{value}</p><p>Amount: #{amount}</p>", :type => 'html'
      
      entry.author do |author|
        author.name "admin"
      end 
    end
  end

  
end