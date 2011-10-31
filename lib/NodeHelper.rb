class NodeHelper


  def initialize(nodepath, client_info, debug = false)
    
    @settings = {}
    @settings['pubsub.server'] = client_info[:node_service]
    @settings['jid'] = client_info[:id]
    @settings['password'] = client_info[:psword]
    @settings['server'] = client_info[:host]
    
    @nodepath = nodepath
    
    # connect XMPP client
    @client = Jabber::Client.new(Jabber::JID.new(@settings['jid']))
    # remove "127.0.0.1" if you are not using a local ejabberd
    @client.connect(@settings['server'])
    @client.auth(@settings['password'])
    @client.send(Jabber::Presence.new.set_type(:available))
    sleep(1)
    
    @servicehelper = Jabber::PubSub::ServiceHelper.new(@client, @settings['pubsub.server'])
    
    @@debugmode = debug
    
  end


  def createNode(publicNode = true)
    config = nil
    begin
      if publicNode
        config = Jabber::PubSub::NodeConfig.new(@nodepath, "pubsub#publish_model" => "open")
      end
      @servicehelper.create_node(@nodepath, config)
    rescue Exception => e
      printE(e)
      if e.to_s == "conflict: "
        puts "returning still true.."
        return true
      end
      
      return false
    end
    return true
  end

  
  def getNodeConfig
    
    parsed = {}
    begin
      res = @servicehelper.get_config_from(@nodepath)  
      if res
  res = res.first
  
  res.each do |k|
    if @@debugmode
      puts k.var
      puts k.type
      puts k.label
      puts k.value
      puts "---------------------------------------------------------------------"
    end
    temp = {:value => k.value, :type => k.type.to_s, :label => k.label }
    parsed.merge!({k.var => temp})
  end
  
      else
  return false
      end
      
    rescue Exception => e
      return false
    end
    return parsed
  end

  
  
  def deleteNode
    begin
      @servicehelper.delete_node(@nodepath)
    rescue Exception => e
      printE(e)
      return false
    end
    return true
  end


  def configNode(configKey, configValue)
    begin
      config = Jabber::PubSub::NodeConfig.new(@nodepath, configKey => configValue)
      @servicehelper.set_config_for(@nodepath, config)
    rescue Exception => e
      printE(e)
      return false
    end
    return true
  end

  
  
  def publishToNode(message, element = "notification")
    begin
puts "1"
      item = Jabber::PubSub::Item.new
puts "2"
      #xml = REXML::Element.new(element)
puts "3"
      #xml << message
      #xml.text = message
puts "4"

      #xml = REXML::Document.new(message)
      xx = item.add(message)
      print xx
puts "5"

puts item.to_s

      @servicehelper.publish_item_to(@nodepath, item)
puts "6"
    rescue Exception => e
      printE(e)
      return false
    end
    return true
  end

  
  def subscribeToNode
    begin
      @servicehelper.subscribe_to(@nodepath)
    rescue Exception => e
      printE(e)
      return false
    end
    return true
  end
  
  def unsubscribeFromNode(subsid)
    begin
      @servicehelper.unsubscribe_from(@nodepath, subsid)
    rescue Exception => e
      printE(e)
      return false
    end
    return true
  end
  
  
  
  private
  
  def printE(e)
    if @@debugmode and @@debugmode == true
      puts "Error: #{e.to_s}"
      #puts "I#{e.to_s}I"
      #puts "  -- line: #{e.backtrace[0].to_s}"
    end
  end

end