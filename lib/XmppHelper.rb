class XmppHelper
  

def self.test
  puts "testikkeli.."
end


############################# Basic sending ###################################

  def self.sendXmppMessage(receiver, message)
    begin
      puts "Lahtee: " + message
      if receiver == ""
      return
      end
      MiddleMan.worker(:xmpp_worker).async_sendMessage(:arg => {:receiver=>receiver,:message=>message})
    rescue Exception => ee
      putsE(ee)
    end
  end




    def self.putsE(e)
        puts "Error sending XMPP message: #{e.to_s}".background(:blue)
        puts "  -- line: #{e.backtrace[0].to_s}"
    end













################################ Node #########################################
  def self.createXmppNode(node_path)
      begin
        if node_path == ""
          return
        end

      return NodeHelper.new(node_path, @@node_client_info).createNode
        rescue Exception => ee
        putsE(ee)
      end
  end

=begin
  def self.publishToXmppNode(node_path, message, client_info, element_name = nil)
      if node_path == "" or message == "" or client_info == nil
        return
      end
      #args = {:node_name => node_name, :message => message, :element_name => element_name}
      MiddleMan.worker(:xmpp_worker).async_publishToNode(:arg => {:node_path => node_path, :message => message, :element_name => element_name, :client_info => client_info})
  end
=end


  def self.getMyNodes(client_info, shortnames = false)
    begin
      my = []
      begin
        
        @client = Jabber::Client.new(Jabber::JID.new(client_info[:id]))
        @client.connect(client_info[:host])
        @client.auth(client_info[:psword])
        @client.send(Jabber::Presence.new.set_type(:available))
        sleep(0.2)
        @servicehelper = Jabber::PubSub::ServiceHelper.new(@client, client_info[:node_service])
        res = @servicehelper.get_affiliations
        
        puts "RESSU: " + res.to_s
        
        res.each do |node, symbol|
      if symbol == :owner
        begin
          puts "nodee: " + node.to_s
          my << node.to_s
        rescue Exception => p
          puts p
        end
      end
        end
      rescue Exception => e
        puts e
        return false
      end
      
      if shortnames
        res = {}
        s = "home/#{client_info[:host]}/#{client_info[:plain_id]}/"
        my.each do |name|
          if name == "http://jabber.org/protocol/tune"
            next
          end
          s = name.strip
          s = s.sub!("home/","")
          if s == nil
            next
          end
          s = s.sub!(client_info[:host]+'/',"")
          if s == nil
            next
          end
          s = s.sub!(client_info[:plain_id]+'/',"")
          if s == nil
            next
          end
          
          puts "s: #{s} : name: #{name}"
          
          res.merge!({s.to_s.strip => name.to_s.strip})
        end
        return res
      end
      
      return my
    
    rescue Exception => ee
      putsE(ee)
      return []
    end
    
  end






############################ Context related ##################################
def self.createContextGeneralNode
  
    begin
      # Creates node for the context
      node_path = "home/#{@@xmpp_host.strip}/#{@@node_client_info[:plain_id].strip}/contexts".strip
      node_service = @@node_client_info[:node_service]
      
      NodeHelper.new(node_path, @@node_client_info, true).createNode
      
      return node_path, node_service
    rescue Exception => ee
      putsE(ee)
      return false
    end
end


def self.publishToContextGeneralNode(context, message_text="New Context Created!", status = "context-created")
    begin
      
      if not context
        puts "No Context!"
        return
      end
      
      
      users = REXML::Element.new "members"
      
      sql = "SELECT users.* 
             FROM context_group_permissions, groups, usersingroups, users 
             WHERE context_group_permissions.context_id=#{context.id} AND 
                   context_group_permissions.group_id = groups.id AND 
                   groups.id=usersingroups.group_id AND usersingroups.user_id=users.id;"
      members = User.find_by_sql(sql)
      members.each do |member|
        #users << "<username>#{member.username}</username>"
        temp_el = REXML::Element.new "username"
        temp_el.text = member.username
        users.elements << temp_el
      end
      
      private = context.private ? "true" : "false"
      context_uri = "#{@@http_host}/contexts/#{context.context_hash}.atom"
      context_node = "home/#{@@xmpp_host.strip}/#{@@node_client_info[:plain_id].strip}/#{context.context_hash}".strip
      node_service = @@node_client_info[:node_service]
      notification_id = Digest::SHA1.hexdigest("#{Time.now.to_s}#{context_node}")
      
      
      message = REXML::Element.new "notification"
      message.attributes["status"] = status 
      message.attributes["notification-id"] = notification_id
      
      temp_el = REXML::Element.new "context_hash"
      temp_el.text = context.context_hash
      message.elements << temp_el
      
      temp_el = REXML::Element.new "context_owner"
      temp_el.text = context.user.username
      message.elements << temp_el
      
      temp_el = REXML::Element.new "metadata_uri"
      temp_el.text = context_uri
      message.elements << temp_el
      
      temp_el = REXML::Element.new "context_owner_named"
      temp_el.text = context.name
      message.elements << temp_el
      
      temp_el = REXML::Element.new "context_xmpp_node"
      temp_el.text = context_node
      message.elements << temp_el
      
      temp_el = REXML::Element.new "context_xmpp_node_service"
      temp_el.text = node_service
      message.elements << temp_el
      
      temp_el = REXML::Element.new "message"
      temp_el.text = message_text
      message.elements << temp_el
      
      message.elements << users
      
      temp_el = REXML::Element.new "private_context"
      temp_el.text = private
      message.elements << temp_el
      
=begin      
      message = 
'<notification status="' + status + '">
  <context_hash>' + context.context_hash + '</context_hash>
  <context_owner>' + context.user.username + '</context_owner>
  <metadata_uri>' + context_uri + '</metadata_uri>
  <context_owner_named>' + context.name + '</context_owner_named>
  <context_xmpp_node>' + context_node + '</context_xmpp_node>
  <context_xmpp_node_service>' + node_service + '</context_xmpp_node_service>
  <message>' + message + '</message>
  <members>' + users + '  </members>
  <private_context>' + private + '</private_context>
</notification>' 
=end      
      
      
      node_path = "home/#{@@xmpp_host.strip}/#{@@node_client_info[:plain_id].strip}/contexts".strip
      
      return NodeHelper.new(node_path, @@node_client_info).publishToNode(message)
    rescue Exception => ee
      putsE(ee)
      return false
    end
end








  def self.publishToContextNode(context_hash, message)
    begin
      node_path = "home/#{@@xmpp_host.strip}/#{@@node_client_info[:plain_id].strip}/#{context_hash}".strip        
      
      puts "node_path: #{node_path}"
      
      return NodeHelper.new(node_path, @@node_client_info).publishToNode(message)
    rescue Exception => ee
      putsE(ee)
      return false
    end
  end
  
  
  
  def self.createContextNode(context_hash)
    begin
      # Creates node for the context
      node_path = "home/#{@@xmpp_host.strip}/#{@@node_client_info[:plain_id].strip}/#{context_hash}".strip
      node_service = @@node_client_info[:node_service]
      
      NodeHelper.new(node_path, @@node_client_info, true).createNode
      
      return node_path, node_service
    rescue Exception => ee
      putsE(ee)
      return false
    end
  end








############################ Notifications ####################################
  def self.notificationToContextNode(devfile, context, msg = "File added to context!", status = "")
    begin
      brp = BlobRepresentation.new(devfile.blob_id)
      essence_uri = @@http_host + "/user/" + devfile.device.user.username + "/device/" + devfile.device.dev_name + "/essence" + devfile.path + devfile.name
      metadatas_uri = @@http_host + "/user/" + devfile.device.user.username + "/device/" + devfile.device.dev_name + "/metadata" + devfile.path + devfile.name
=begin
      message = REXML::Document.new(
'<notification>
  <essence_uri>' + essence_uri + '</essence_uri>
  <metadata_uri>' + metadatas_uri + '</metadata_uri>
  <context_name>' + context.name + '</context_name>
  <context_owner>' + context.user.username + '</context_owner>
  <message>' + message + '</message>
  <representation format="yaml">' + YAML.dump_stream(brp.to_yaml) +
 '</representation>
</notification>')
=end

=begin
      message = 
'<notification>
  <essence_uri>' + essence_uri + '</essence_uri>
  <metadata_uri>' + metadatas_uri + '</metadata_uri>
  <context_name>' + context.name + '</context_name>
  <context_owner>' + context.user.username + '</context_owner>
  <message>' + message + '</message>
  <representation format="yaml">' + YAML.dump_stream(brp.to_yaml) +
 '</representation>
</notification>'      
=end

puts "1"
      message = REXML::Element.new "notification"
      message.attributes["status"] = status 
      
      temp_el = REXML::Element.new "essence_uri"
      temp_el.text = essence_uri
      message.elements << temp_el
      
      temp_el = REXML::Element.new "metadata_uri"
      temp_el.text = metadatas_uri
      message.elements << temp_el
      
      temp_el = REXML::Element.new "context_name"
      temp_el.text = context.name
      message.elements << temp_el
      
      temp_el = REXML::Element.new "context_owner"
      temp_el.text = context.user.username
      message.elements << temp_el
      
      temp_el = REXML::Element.new "message"
      temp_el.text = msg
      message.elements << temp_el
      
      temp_el = REXML::Element.new "representation"
      temp_el.attributes["format"] = "yaml"
      temp_el.text = YAML.dump_stream(brp.to_yaml)
      message.elements << temp_el
      

puts "2"

      return NodeHelper.new(context.node_path, @@node_client_info).publishToNode(message)
    rescue Exception => ee
      putsE(ee)
      return false
    end
  end





def self.notificationToNode(fileobserver, devfile, message = "File added to context!")
   begin
        brp = BlobRepresentation.new(devfile.blob_id)
        essence_uri = @@http_host + "/user/" + devfile.device.user.username + "/device/" + devfile.device.dev_name + "/essence" + devfile.path + devfile.name
        metadatas_uri = @@http_host + "/user/" + devfile.device.user.username + "/device/" + devfile.device.dev_name + "/metadata" + devfile.path + devfile.name
message = 
'<notification>
  <essence_uri>' + essence_uri + '</essence_uri>
  <metadata_uri>' + metadatas_uri + '</metadata_uri>
  <message>' + message + '</message>
  <representation format="yaml">' + YAML.dump_stream(brp.to_yaml) +
 '</representation>
</notification>'      

      
      return NodeHelper.new(fileobserver.node_path, @@node_client_info).publishToNode(message)
    rescue Exception => ee
      putsE(ee)
      return false
    end  
  end








############################# USER NODE NOTIFICATIONS ######################################

def self.pushToUserNode_invited_or_uninvaited_from_context(user, context, invited = true)
  
  
    readable_context_name = ContextName.find(:first, :conditions => ["user_id = ? and context_id = ?", user.id, context.id])
    if readable_context_name
      readable_context_name = readable_context_name.name
    else
      readable_context_name = context.user.username + "'s " + context.name
    end
    
    if invited
      status = "invited-to-context"
      message_text = "you were invited to #{readable_context_name} context"
    else
      status = "uninvited-to-context"
      message_text = "you were uninvited to #{readable_context_name} context"
    end
  
    private = context.private ? "true" : "false"
    context_uri = "#{@@http_host}/contexts/#{context.context_hash}.atom"
    context_node = "home/#{@@xmpp_host.strip}/#{@@node_client_info[:plain_id].strip}/#{context.context_hash}".strip
  
    message = REXML::Element.new "notification"
    message.attributes["status"] = status 
    
    temp_el = REXML::Element.new "context_hash"
    temp_el.text = context.context_hash
    message.elements << temp_el
    
    temp_el = REXML::Element.new "context_owner"
    temp_el.text = context.user.username
    message.elements << temp_el
    
    temp_el = REXML::Element.new "metadata_uri"
    temp_el.text = context_uri
    message.elements << temp_el
    
    temp_el = REXML::Element.new "context_owner_named"
    temp_el.text = context.name
    message.elements << temp_el
    
    temp_el = REXML::Element.new "readable_context_name"
    temp_el.text = readable_context_name
    message.elements << temp_el
    
    temp_el = REXML::Element.new "context_xmpp_node"
    temp_el.text = context_node
    message.elements << temp_el
        
    temp_el = REXML::Element.new "message"
    temp_el.text = message_text
    message.elements << temp_el
    
    temp_el = REXML::Element.new "private_context"
    temp_el.text = private
    message.elements << temp_el
    
    print "Pushing to user node"
    pushToUserNode(user, message, status)
  
end



#
#   Pushes message to user's user_psnode.
#   user: user object
#   ensureNode: makes sure that user has the user_psnode, if not creates it
#   status: invited-to-context, uninvited-to-context
#   message: REXML object
#
#
def self.pushToUserNode(user, message, status, ensureNode = true)

    if ensureNode
      if not user.user_psnode or user.user_psnode == ""
        puts "creating user_psnode..."
        if createUserPsNode(user)
          puts "Node was created/ensured"
        else
          puts "Error in ensuring node.."
          return
        end
      end
    end
    
    
    begin
      
      node_path = user.user_psnode
      puts "user_psnode: #{node_path}"
      
      return NodeHelper.new(node_path, @@node_client_info).publishToNode(message)
    rescue Exception => ee
      puts "pushToUserNode:"
      putsE(ee)
      return false
    end

end



def self.createUserPsNode(user)
    begin
      # Creates node for user
      node_path = "home/#{@@xmpp_host.strip}/#{@@node_client_info[:plain_id].strip}/user/#{user.username}/node".strip
      node_service = @@node_client_info[:node_service]
      
      if NodeHelper.new(node_path, @@node_client_info, true).createNode
        user.update_attribute(:user_psnode, node_path)
        return true #node_path, node_service
      else
        puts "Faaalsee.."
        return false
      end
      
    rescue Exception => ee
      puts "createUserPsNode"
      putsE(ee)
      return false
    end
end





end



















