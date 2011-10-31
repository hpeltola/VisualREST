# xmpp_worker is used for sending and receiving xmpp-messages. Received messages must be in xmpp2rest-format, 
# which is defined in dtd: public/dtd/xmpp2rest_api.dtd
class XmppWorker < BackgrounDRb::MetaWorker
 
  # Client that is used for sending xmpp-messages
  @send_client = nil
  
  # Client that is used to receive xmpp2rest-messages
  @receive_client = nil
  
  set_worker_name :xmpp_worker

  # This method is called, when worker is loaded for the first time
  #
  def create(args = nil)
    # Connects to the xmpp-client that is used for sending xmpp-messages
    @send_client = connect(@@send_client_info)
    
    # Connect to xmpp-client that is used for receiving messages that are then turn into http-requests
    @receive_client = connect(@@receive_client_info)
    runMessageReceiver
        
    # Ensures that xmpp-server has node: home/host/<host>/<node_account>/contexts
    XmppHelper::createContextGeneralNode

  end
  
  # General method for connecting to xmpp-server
  #
  def connect(client_info)
    
    begin
      client = nil
      puts "XMPP Connecting to jabber server " + client_info[:host] + ":" + client_info[:port].to_s
      puts "XMPP Account " + client_info[:id]
      client.close if client != nil
      #full_id = "#{client_info[:id]}@#{client_info[:host]}"
      jid = Jabber::JID::new(client_info[:id])
      client = Jabber::Client::new(jid)
    rescue Exception => e
      puts e.to_s
    end

    connected = false
    while not connected

      begin
        Timeout::timeout(10) do 
          client.connect(client_info[:host], client_info[:port])
          client.auth(client_info[:psword])
          client.send(Jabber::Presence.new.set_type(:available))
          connected = true
        end
      rescue => e
        puts "XMPP Exception in connecting: " + e + "\n"
        client.close
      end
    end
    puts "XMPP Connected"
    return client
  end
  
  
  
###############################################################################
#                                                                             #
#         SEND: XMPP                                                          #
#                                                                             #
###############################################################################
  
  
  
  
  
  
  
  # General method for sending xmpp-messages. 
  #
  # Notce! client-parameter contains the client that is used to send the message,
  # not the client that is receving the message
  #
  def sendMessage(args, client = @send_client)
    jabmsg = Jabber::Message::new(args[:receiver], args[:message]).set_type(:chat).set_id('1')
    
    begin 
      Timeout::timeout(10) do
        client.send(jabmsg)
        puts "XMPP TO: " + args[:receiver].to_s
        puts "XMPP MESSAGE: " + args[:message].to_s
      end

    rescue => e
      puts "XMPP Exception in sending: " + e + "\n"
      puts "XMPP Reconnecting to server and trying again"
      puts "  (-- line #{e.backtrace[0].to_s} )"
      if client == @receive_client
        puts "re-connecting to RECEIVE_client"
        connect(@receive_client)
      else
        puts "re-connecting to SEND_client"
        connect(@@send_client_info)
      end
      retry
    end
  end
  
  
  
  
  
  # General method for sending XML stanzas. Ignores warning, which prevents sending further stanzas..
  def sendStanza(client_info, xml)
    Thread.new{
      client = connect(client_info)#Client.new(JID.new(client_info[:id]))
      #client.connect
      #client.auth(client_info[:psword])
      #client.send(Jabber::Presence.new.set_type(:available))
      begin
      Timeout::timeout(5) {
        client.send_with_id(xml)
        puts "Stanza sent (1)"
      }
      rescue Exception => t
        puts t.to_s
      end
      puts "Stanza sent (2)"
    }
  end
  
  
  
=begin
###############################################################################
#                                                                             #
#         PUBSUB stuff                                                        #
#                                                                             #
###############################################################################
  
  
  
  
  
  
  
  # args: node_path, client_info
  def createNode(args)
      #Jabber::debug = true
      
      # The id of the node MUST follow this structure!!!
      if args[:node_path] == nil or args[:node_path] == ""
        puts "Node name missing!"
        raise Exception.new("Node name missing!")
      elsif args[:client_info] == nil
        puts "client_info missing!"
        raise Exception.new("client_info missing!")
      end
      
          
      pubsub_client = connect(args[:client_info])
      
      begin

        node_path = args[:node_path].to_s.strip #"home/#{@@xmpp_host.strip}/#{client_info[:plain_id].strip}/#{args[:node_name].strip}".strip
        service_name = 'pubsub.'+args[:client_info][:host] #"pubsub.#{@@xmpp_host}"
xml = '<iq type="set" from="' + args[:client_info][:id] + '" to="' + args[:client_info][:node_service] + '" id="create1">
        <pubsub xmlns="http://jabber.org/protocol/pubsub">
        <create node="' + node_path + '"/>
        <configure/>
        </pubsub>
       </iq>'
       
       sendStanza(args[:client_info], xml)
        #begin
        #  pubsub_client.send_with_id(xml)
        #rescue Exception => jep
        #  puts "Error"
        #end
        
        #puts "Node #{node_path} created!"




# These are working only time to time        
#        pubsub = Jabber::PubSub::ServiceHelper.new(pubsub_client, service_name)
#        pubsub.create_node(node_path)

      rescue Exception => e #Jabber::ServerError => e
        
        if e.inspect.to_s == "#<Jabber::ServerError: conflict: >"
          m = "The node already exists!"
          puts m
          return true
        elsif e.inspect.to_s == "#<Jabber::ServerError: forbidden: >"
          m = "The node path is wrong: #{node_path}. The right format is: home/<hostname>/username/whatever. \n Also make sure that the base node: home/<hostname>/username/ everything between has been created!"
          puts m
          puts "Error: #{e.to_s}"
          puts "  -- line: #{e.backtrace[0].to_s}"
          return false
        else
          m = "Other error.."
          puts m
          puts "Error: #{e.to_s}"
          puts "  -- line: #{e.backtrace[0].to_s}"
          return false        
        end
      end
      
      return true
  end
  
  
  
  
  
  
  
  
  
  
  
  
  # args: node_path, message, client_info, optinals: element_name
  def publishToNode(args)#, client_info = @@node_client_info)
    
    if args[:node_path] == nil or args[:node_path] == ""
      puts "Node name missing!"
      raise Exception.new("Node name missing!")
    elsif args[:message] == nil or args[:message] == ""
      puts "Message missing!"
      raise Exception.new("Message missing!")
    elsif args[:client_info] == nil
      puts "client_info missing!"
      raise Exception.new("client_info missing!")
    end
    
    element_name = args[:element_name] ? args[:element_name] : "nofification" 
    
    node_path = args[:node_path] #"home/#{args[:client_info][:host].strip}/#{args[:client_info][:plain_id].strip}/#{args[:node_path].strip}".strip
    service_name = "pubsub.#{args[:client_info][:host].strip}"
        
    pubsub_client = connect(args[:client_info])
  
    pubsub = Jabber::PubSub::ServiceHelper.new(pubsub_client, service_name)
    item = Jabber::PubSub::Item.new
    xml = REXML::Element.new(element_name)
    xml.text = args[:message]
    
    item.add(xml);
    # publish item
    pubsub.publish_item_to(node_path, item)
    
    puts "Message: #{args[:message]} published to node: #{node_path}"
    sleep(1)
    pubsub_client.close
    
    
  end
  
=begin
  # An initializers that makes sure that every context has node
  def ensureContextNodes
    puts "Initializing context nodes..."
    
    Context.find(:all).each do |context|
      #puts "Context node name: #{context.node_path.to_s}, #{context.node_service.to_s}"
      if not context.node_path or not context.node_service
        puts "Context: #{context.name} has no node yet!"
        node_path = "home/#{@@xmpp_host}/#{@@node_client_info[:plain_id]}/#{context.context_hash}"
        
        args = {:node_path => node_path, :client_info => @@node_client_info}
        if createNode(args) 
          context.update_attribute(:node_path, node_path)
          context.update_attribute(:node_service, @@node_client_info[:node_service])
        end
      end
    end
    
    puts "Initializing context nodes finished!"
  end
=end  
  
  

  
  
  
###############################################################################
#                                                                             #
#         RECEIVE: XMPP2REST                                                  #
#                                                                             #
###############################################################################  
  
  
  
  
  # Connect to jabber server and define callback
  #
  def runMessageReceiver
    
    # DTD which against the xml-messages are validated to
    @dtd = XML::Dtd.new("public", @@xmpp_xml_dtd)
    
    @receive_client.add_message_callback { |msg|
      
      Thread.new{
        handleMessage(msg)
      }

      } #add_message_callback

  end
  
  
  # Handles xmpp2rest-messages that are received.
  #
  def handleMessage(msg)
          if msg != nil and msg.type == :chat and msg.body #and msg.from == @@visualRESTmain
          #puts "#{msg.from}:"
          #puts "#{msg.body.strip}"
                  
          puts "Validating.."
          
          begin
            
            doc = XML::Document.string(msg.body)
            
            doc.validate(@dtd)
            puts "..xml was valid".background(:green)
          rescue => e
            puts "..xml NOT valid!".background(:red)
            notification = {:receiver => msg.from, :message => "xml not valid"}
            sendMessage(notification, @receive_client)
            return
          end
  
          puts "Parsing.."
          begin
          
            method = (doc.find_first('//xmpp2rest/method')) ? doc.find_first('//xmpp2rest/method').content.to_s : nil
            method = method.downcase        
            case method
            
              when 'create'
                Thread.new{
                  createResouce(doc, msg.from)
                }
              when 'read'
                Thread.new{
                  readResouce(doc, msg.from)
                }
              when 'update'
                Thread.new{
                  updateResouce(doc, msg.from)
                }
              when 'delete'
                Thread.new{
                  deleteResource(doc, msg.from)
                }
              else
              puts "unknown method"
            end
          
          rescue Exception => e
            puts "Problem in parsing xml-filelist: " + e.to_s
            puts "  --line " + e.backtrace[0].to_s     
          end
        end
  end
  
  
  
  
  
  
  
  
  # Method for creating resource/resources. Uses HTTP PUT to localhost
  #
  def createResouce(doc, msg_from)

    begin
        
        puts "Creating"
        
        path = ""
        params = {}
        headers = {}
        
    
        context, path = findContext(doc, path)
          
          # Adding the actual parameters according the context
        if context

          # if device context is not given -> creating new user
          if context == :userdevice 
            params = parseUserData(doc, params)
          
          # if user-group -context and name for the group is given -> creating new group
          elsif context == :user_group
            params = {}
          
          # if user-group-member -context and name for member is given -> adding new member to group
          elsif context == :user_group_member
            params = {}
          
          # if device-context and name for the device is given -> creating new device
          elsif not doc.find_first('//xmpp2rest/user/device/files') and devicename
            params = parseDeviceData(doc, params)
            
          # If files element was given -> sending filelist
          elsif doc.find_first('//xmpp2rest/user/device/files')
            puts "..files"
            params, path = parseFileslist(doc, params, path)
          
          # Error
          else
            raise Exception.new("Context was not found!")
          end
        
        
        
        # System-based context
        else
          puts "System context:"
          if doc.find_first('//xmpp2rest/metadata')
            puts "..metadata"
            metadata_type = (doc.find_first('//xmpp2rest/metadata').attributes.get_attribute("metadata_type")) ? doc.find_first('//xmpp2rest/metadata').attributes.get_attribute("metadata_type").value : nil
            puts metadata_type.to_s
            if not metadata_type
              raise Exception.new("Malformed path: metadata-element must contain metadata_type -attribute!")
            else
              path += "/metadatatype/#{metadata_type}"
            end
          end
        end


        httpAndNotify(path, params, msg_from, :put)
        
    rescue Exception => e
      puts "Problem in parsing data (CREATE) from xml or sending http request to the VR server: " + e
      puts "  -- line: #{e.backtrace[0].to_s}"
    end

  end



  # Method for updating resource/resources. Uses HTTP POST to localhost
  #
  def updateResouce(doc, msg_from)

    begin
        
      puts "Updating"
      
      path = ""
      params = {}
      headers = {}

      context, path = findContext(doc, path)
      
      if context == :user
        params = {}
      elsif context == :user_group
        params = {}
      elsif context == :user_device
        # Checks if files element was given and parses file's updated metadata
        if doc.find_first('//xmpp2rest/user/device/files')
          puts "..files"
          params = parseUpdatedMetadata(doc, params, path)
          params.each do |p|
            httpAndNotify(p[:path], p[:params], msg_from, :post)
          end
        
        elsif doc.find_first('//xmpp2rest/user/device/online')
          puts "..online"
          path += "/online"
          params = parseOnlineStatus(doc, params, path)
          httpAndNotify(path, params, msg_from, :post)
        
        elsif doc.find_first('//xmpp2rest/user/device/filerights')
          puts "..filerights"
          params, filepath = parseFilerights(doc, params, path)
          path += "/filerights/#{filepath}"
          httpAndNotify(path, params, msg_from, :post)
        end
        
        
       else
         raise Exception.new("No context found!")
       end
            

    rescue Exception => e
      puts "Problem in parsing data (UPDATE) from xml or sending http request to the VR server: " + e
      puts "  -- line: #{e.backtrace[0].to_s}"
    end

  end
  
  
  # Method for deleting resource/resources. Uses HTTP DELETE to localhost
  #
  def deleteResource(doc, msg_from)
  
    
    begin

      puts "Deleting"

      path = ""
      params = {}
      headers = {}
      
      context, path = findContext(doc, path)  
  
      # Deleting member from group
      if context == :user_group_member
        params = {}
      else
        raise Exception.new("No context given!")
      end
  
      httpAndNotify(path, params, msg_from, :delete)
  
    rescue Exception => e
      puts "Problem in parsing data (CREATE) from xml or sending http request to the VR server: " + e
      puts "  -- line: #{e.backtrace[0].to_s}"
    end
  
  end
  
  
  
  # Finds context from xml, adds parts to path and returns the both results
  #
  def findContext(doc, path)
    
    context = nil
    
    # If user-element is given -> context is user-based, otherwise context is system-based
    if doc.find_first('//xmpp2rest/user')
      puts "User context"
    
      username = (doc.find_first('//xmpp2rest/user').attributes.get_attribute("username")) ? doc.find_first('//xmpp2rest/user').attributes.get_attribute("username").value : nil
      
      # If username not found -> malformed uri
      if not username
        raise Exception.new("Malformed path: /user, use /user/<username> instead!")
      else
        path += "/user/#{username}"
        puts "..user"
        context = :user
      end        
      
      
      # Group-context
      if doc.find_first('//xmpp2rest/user/group')
        puts "..group"
        groupname = (doc.find_first('//xmpp2rest/user/group').attributes.get_attribute("groupname")) ? doc.find_first('//xmpp2rest/user/group').attributes.get_attribute("groupname").value : nil
        # If group-context is given, but groupname not found -> malformed uri
        if not groupname
          raise Exception.new("Malformed path: ../group, use /group/<groupname> instead!")
        elsif doc.find_first('//xmpp2rest/user/group/user')
          membername = (doc.find_first('//xmpp2rest/user/group/user').attributes.get_attribute("username")) ? doc.find_first('//xmpp2rest/user/group/user').attributes.get_attribute("username").value : nil
          if not membername
            raise Exception.new("Malformed path: ../member, use ..member/<username> instead!")
          end
          puts "..member"
          path += "/group/#{groupname}/member/#{membername}"
          context = :user_group_member
        else
          path += "/group/#{groupname}"
          context = :user_group
        end         
      end
 
          
      # Device-context
      if doc.find_first('//xmpp2rest/user/device')
        puts "..device"
        devicename = (doc.find_first('//xmpp2rest/user/device').attributes.get_attribute("devicename")) ? doc.find_first('//xmpp2rest/user/device').attributes.get_attribute("devicename").value : nil
        # If device-context is given, but devicename not found -> malformed uri
        if not devicename
          raise Exception.new("Malformed path: ../device, use ../device/<devicename> instead!")
        else
          path += "/device/#{devicename}"
          context = :user_device
        end
      end
    end
    
    return context, path
  end
  
  
  
  
  # Parses filerights for specific file and translates those to that kind of form that vR understands
  #
  def parseFilerights(doc, params, path)
  
    fullpath = doc.find_first('//xmpp2rest/user/device/filerights').attributes.get_attribute('fullpath') ? doc.find_first('//xmpp2rest/user/device/filerights').attributes.get_attribute('fullpath').value : nil
    if not fullpath
      raise Exception.new('No fullpath given for changing filerights!')
    end
    
    # Checking if public-element (with: true-value) is given -> public file
    allow_public = doc.find_first('//xmpp2rest/user/device/filerights/public/allow') ? true : false
    if allow_public
      params.merge!({"public"=>'true'})
    end
    
    
    # Checking if groups are given -> private file
    doc.find('//xmpp2rest/user/device/filerights/groups/group').each do |group_element|
      
      groupname = (group_element.attributes.get_attribute("groupname")) ? group_element.attributes.get_attribute("groupname").value : nil
      if group_element.find_first('allow')
        params.merge!({"group:#{groupname}" => '1'})
      elsif group_element.find_first('deny')
        params.merge!({"group:#{groupname}" => '0'})
      else
        next
      end
    end

    return params, fullpath
  end
  
  
  # Parses dev_type and password from xml
  #
  def parseDeviceData(doc, params)
  
    dev_type = (doc.find_first('//xmpp2rest/user/device/dev_type')) ? doc.find_first('//xmpp2rest/user/device/dev_type').content : nil
    password = (doc.find_first('//xmpp2rest/user/device/password')) ? doc.find_first('//xmpp2rest/user/device/password').content : nil
    
    if not dev_type or not password
      raise Exception.new("Missing elements data for creating new device!")
    end 
    
    params.merge!({:dev_type => dev_type})
    params.merge!({:password => password})
  
    return params
  end
  
  
  
  # Parses user's real name and password from xml
  #
  def parseUserData(doc, params)
    
    real_name = (doc.find_first('//xmpp2rest/user/real_name')) ? doc.find_first('//xmpp2rest/user/real_name').content : nil
    password = (doc.find_first('//xmpp2rest/user/password')) ? doc.find_first('//xmpp2rest/user/password').content : nil
    
    if not real_name or not password
      raise Exception.new("Missing elements data for creating new user!")
    end 
    
    params.merge!({:real_name => real_name})
    params.merge!({:password => password})
    
    return params
  end
  
  
  
  
  
  # Parses device's online status, and the possible status elements that are given
  #
  def parseOnlineStatus(doc, params, path)
    
    status = {}
    
    doc.find('//xmpp2rest/user/device/online/status').each do |status_element|
   
      status_key = (status_element.attributes.get_attribute("status_key")) ? status_element.attributes.get_attribute("status_key").value : nil
      
      if not status_key or status_key == ""
        raise Exception.new("Error in status_key -attribute. (Must be given, and cannot be empty!)")
      elsif not status_element.content or status_element.content == ""
        raise Exception.new("Status element must have content!")
      end
      
      if status_key == "device_location" and 
         status_element.find_first("location/latitude") and status_element.find_first("location/longitude") and
         status_element.find_first("location/latitude").content and status_element.find_first("location/longitude").content
          
        location = {}
        location.merge!({'latitude' => status_element.find_first("location/latitude").content.to_f})
        location.merge!({'longitude' => status_element.find_first("location/longitude").content.to_f})
        status.merge!({:device_location => YAML.dump(location)})
      
      elsif status_key == "uploading_file" and
         status_element.find_first("uploading_file") and status_element.find_first("uploading_file_hash") and
         status_element.find_first("uploading_file").content and status_element.find_first("uploading_file_hash").content

        status.merge!({'uploading_file_hash' => status_element.find_first("uploading_file_hash").content.to_s})
        status.merge!({'uploading_file' => status_element.find_first("uploading_file").content.to_s})
        
      else status_key != "device_location" and status_key != "uploading_file" and status_element.content
        status.merge!({status_key => status_element.content.to_s})
      end 
    end
    params.merge!({:status => YAML.dump(status)})
    return params
  end
  
  
  
  
  
  
  
  
  
  # Parses the user-specific metadata from xml to visualREST form. 
  # List of updated files is returned, so that xml can contain many metadata changes for different files
  #
  def parseUpdatedMetadata(doc, params, path)
  
    path += "/files"
    
    listOfUpdatedFiles = Array.new
    doc.find('//user/device/files/file').each do |file|

      fullpath = (file.attributes.get_attribute("fullpath")) ? file.attributes.get_attribute("fullpath").value : nil          

      version = "not_found"
      if file.find_first('version')
        version = (file.find_first('version').attributes.get_attribute("num")) ? file.find_first('version').attributes.get_attribute("num").value.to_i : nil      
      end
      
      if fullpath.to_s == ""
        raise Exception.new("fullpath cannot be empty")
      elsif fullpath[0] == '/'
        raise Exception.new("path cannot begin with /")
      elsif not version
        raise Exception.new("Error in version element")
      end

      temp_path = (version) == "not_found" ? path + "/#{fullpath}" : path + "/#{fullpath}" + "?version=#{version.to_s}"
      
      file.find("metadata").each do |mdata|
        mtype = mdata.attributes.get_attribute("metadata_type") ? mdata.attributes.get_attribute('metadata_type').value : nil
        mvalue = mdata.content
        if not mtype or not mvalue
          raise Exception.new("Malformed metadata element")
        end
        listOfUpdatedFiles << {:path => temp_path, :params => {:metadata_type => mtype.to_s, :metadata_value => mvalue.to_s}}
      end
    end
    

    listOfUpdatedFiles.each do |v|      
      puts "#{v[:path]} #{v[:params][:metadata_type]} #{v[:params][:metadata_value]}"
    end
    
    
    return listOfUpdatedFiles
  end






  # Parses filelist and translates it to visualREST form
  #
  def parseFileslist(doc, params, path)
    prev_commit_hash = (doc.find_first('//xmpp2rest/user/device/files/prev_commit_hash') ? doc.find_first('//xmpp2rest/user/device/files/prev_commit_hash').content : nil)        
    commit_hash = (doc.find_first('//xmpp2rest/user/device/files/commit_hash')) ? doc.find_first('//xmpp2rest/user/device/files/commit_hash').content : nil
    
    if not commit_hash
      raise Exception.new("Missing element: commit_hash")
    end
    
    puts "Prev_commit_hash: " + prev_commit_hash.to_s
    puts "Commit_hash: " + commit_hash.to_s
    
    location = {}
    location['latitude'] = (doc.find_first('//xmpp2rest/user/device/files/location/latitude')) ? doc.find_first('//xmpp2rest/user/device/files/location/latitude').content : "NULL"
    location['longitude'] = (doc.find_first('//xmpp2rest/user/device/files/location/longitude')) ? doc.find_first('//xmpp2rest/user/device/files/location/longitude').content : "NULL"
    
    filelist = Hash.new
    doc.find('//user/device/files/file').each do |file|
      fullpath = (file.attributes.get_attribute("fullpath")) ? file.attributes.get_attribute("fullpath").value : nil          
      filepath = (file.find_first('path')) ? file.find_first('path').content : nil
      filename = (file.find_first('filename')) ? file.find_first('filename').content : nil 
      filedate = (file.find_first('filedate')) ? file.find_first('filedate').content : nil
      filetype = (file.find_first('filetype')) ? file.find_first('filetype').content : nil
      filesize = (file.find_first('filesize')) ? file.find_first('filesize').content : nil
      version_hash = (file.find_first('version_hash')) ? file.find_first('version_hash').content : nil

      if not filepath or not filename or not filetype or not filesize or not filedate or not version_hash
        raise Exception.new("Not all the needed metadata given: filename, filetype, filesize, filedate and version_hash are compulsory!")
      elsif fullpath.to_s != filepath.to_s + filename.to_s
        raise Exception.new("fullpath: #{fullpath.to_s} doesn't match to path + name: #{filepath.to_s + filename.to_s}")
      elsif fullpath[0,1] != '/' or filepath[0,1] != '/'
        raise Exception.new("path must begin with /")
      end
puts "filepath: #{filepath}"
      filelist.merge!({fullpath => {"status" => "created", "blob_hash" => version_hash, "name" => filename, "path" => filepath, "size" => filesize, "filetype" => filetype, "filedate" => filedate.to_s}})     
    end
    contains = YAML.dump_stream(filelist)
puts "contains: #{contains.to_s}"
    if prev_commit_hash
      puts "prev hash added!"
      params['prev_commit_hash'] = prev_commit_hash
    end
    
    path += "/files"
    params.merge!({ 'contains' => contains, 'commit_hash' => commit_hash, 'commit_location' => location})
    return params, path
  end



  # General method for first sending http to visualREST and then returning the response to xmpp-client that
  # sent the xmpp2rest -message
  #
  def httpAndNotify(path, params, msg_from, method)
    message = ""
    begin
      
      m = ""
      if method == :get
        m = "GET"
      elsif method == :post
        m = "POST"
      elsif method == :put
        m = "PUT"
      elsif method == :delete
        m = "DELETE"
      else
        raise Exception.new("Wrong method! use: :get, :post, :put or :delete!")
      end
      
      puts "HTTP #{m} to: #{@@http_host + path}"
      res = HttpRequest.new(method, path, params).send(@@http_host)
      message = "#{res.code.to_s}; #{res.body}; #{path}"
      
    rescue Exception => e
      puts "Error: " + e.to_s
      puts "  -- line #{e.backtrace[0].to_s}"
      message = "#{e.to_s}; #{path}"
    end
  
    # Notifies the xmpp-client about the http-rest result 
    puts "xmpp-response"
    notification = {:receiver => msg_from, :message => message}
    sendMessage(notification, @receive_client)
  
  end





  
  
  
  
  
  
  

end # class end










