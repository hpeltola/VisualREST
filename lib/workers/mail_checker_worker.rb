# Worker: - gets mails from XXXXXX@gmail.com
#         - Goes through users mail accounts and gets new attachments

require 'rubygems'
require 'net/imap'
require 'net/http'
require 'net/https'
require 'tmail'
require 'yaml'
require 'mime/types'



class MailCheckerWorker < BackgrounDRb::MetaWorker
  set_worker_name :mail_checker_worker
 def create(args = nil)
    # this method is called, when worker is loaded for the first time
    
    
    # time argument is in seconds
#    add_periodic_timer(180) { getNewMail }
    puts "mail_checker_worker: Periodic timer not added. Remove row from comments to add timer"
#    getNewMail # Start first iteration immediately
  end
  
    
  # See if there is new mail
  # Tell visualRest uid:s of new mails that have attachments
  def getNewMail

      @@CTYPE_TO_EXT = {
          'image/jpeg' => 'jpg',
          'image/gif'  => 'gif',
          'image/png'  => 'png',
          'image/tiff' => 'tif'
      }
    begin
      
      # Go through users mail accounts for new attachment files
      userEmails = UserEmail.find_all_by_mail_checking(true);
      userEmails.each do |x|
        if x.last_uid == nil
          x.update_attribute(:last_uid, 0)
        end
        container_name = x.mail_server.gsub(/\./, "_")
        if x.device_id != nil
          device = Device.find_by_id(x.device_id)
          if device != nil
            container_name = device.dev_name
          end
        end
        new_uid = goThroughUserEmails(x.user_id, x.mail_username, x.mail_password, x.mail_server, x.mail_port, x.mail_tls_encryption, x.last_uid, container_name)
        if new_uid > x.last_uid
          x.update_attribute(:last_uid, new_uid)
        end
      end
    rescue => e
      puts "PROBLEM GOING THROUGH USER EMAILS"
      puts e 
   
    end
      
      
    begin
          
      ## Configurations    
      username = "XXXXXX"
      password = "YYYYYY"
      server = "imap.gmail.com"
      port = 993
              

                      
      # Connect to gmail server
      imap = Net::IMAP.new(server,port,true)
      
      # Login
      imap.login(username, password)
      
      # Select inbox
      imap.select('INBOX')
      
      # get all new mails
      imap.uid_search(["NOT", "DELETED", "NOT", "SEEN"]).each do |uid|
      
        # fetches the source of the email for tmail to parse
        source  = imap.uid_fetch(uid, 'RFC822')
      
        if source == nil
          puts "Couldn't find mail with uid: #{uid}"
          next
        end
      
        source = source.first.attr['RFC822']
        
        # parse with tmail
        email = TMail::Mail.parse(source)  
        
        # Print subject and sender
        #p email.subject  
        #p email.from 
      
       ### Look for hash hidden in receiver name
       username, contextname = findUserAndContext(email.to.to_s)
       if username == nil or contextname == nil
         next
       end
       
       puts "User: #{username}"
       puts "Context: #{contextname}"
       
       user = User.find_by_username(username)
       contextName = ContextName.find_by_username_and_name(username, contextname)
       
       if user == nil or contextName == nil
         next
       end
       
       # Check that user has named email sender as his email account
       useremail = UserEmail.find_by_user_id_and_email(user.id, email.from)
       if useremail == nil
         next
       end
       
       context = Context.find_by_id(contextName.context_id)
       if context == nil
         next
       end
       
       puts "Mail is from account that user has named and context is found"
       
       device = nil
      
        # If has attachments, save them
        if email.has_attachments?
          email.parts.each_with_index do |part, index|
            puts part.content_type
      
            # Text files are ignored. If mail has attachments, body was considerede as attachment.
            if part.content_type == "text/plain" or part.content_type == "multipart/alternative"
              next
            end
            
            # Create device if doesn't already exist
            if device == nil
              # Try to find virtual device or create it
              device = findOrCreateVirtualDevice(user.id, "visualrest_mail_box")
              
              # If device name is already in use for other type of device, 
              if device == nil
                puts "Couldn't create virtual_container with name 'visualrest_mail_box'"
                next
              end
            end  
                     
                    
            filename = part_filename(part)
            content_type = part.content_type
            filename ||= "#{index}.#{ext(part)}"
            file = filename
            fname = file.split(".")
                      
            # If prefix given in topic, add it to filename
            if email.subject.to_s.include?("[p]") 
              # Adds email topic as a prefix for the file
              filename = email.subject.to_s.gsub('[p]', '').strip.gsub(/\r/, '_') + "_" + filename
            end
            
            # Use virtualContainerManager to add the file
            # Create the manager      
            @virtualContainerManager = VirtualContainerManager.new(user, device.dev_name)
        
            # Add file with the manager
            @virtualContainerManager.addFile('/' + filename, part.body)
            
            @virtualContainerManager.addMetadata('/' + filename, "context_hash", context.context_hash)
            
            # Add metadata
            @virtualContainerManager.addMetadata('/' + filename, "mail_topic", email.subject)
            @virtualContainerManager.addMetadata('/' + filename, "mail_from", email.from.to_s.strip)
            
            
            
            # Make the commit
            @virtualContainerManager.commit
                      
            puts "File #{filename} was saved to visualrest"
          end
        end
      end
    
      imap.logout
      imap.disconnect
      
    rescue => e
      puts e
      return
    end  
  end
  
  # Go through users mail accounts
  def goThroughUserEmails(user_id, username, password, server, port, tls, last_uid, virtual_device_name)
    begin
      new_uid = last_uid
                    
      user = User.find_by_id(user_id)
      if user == nil
        return
      end
                      
      # Connect to gmail server
      if tls
        imap = Net::IMAP.new(server,port,false)
      else
        imap = Net::IMAP.new(server,port,true)
      end
      
      # Login
      imap.login(username, password)
      
      # Select inbox
      imap.select('INBOX')
      
      # get all new mails
      tmp_last_uid = (last_uid+1).to_s+":"+(last_uid+101).to_s
      #puts tmp_last_uid
      imap.uid_search(["NOT", "DELETED", "UID", tmp_last_uid]).each do |uid|
        puts "Checking mail with uid: #{uid}"
        #notSeen = false
        #if imap.search(["NOT", "DELETED", "NOT", "SEEN", "UID", uid]) != nil
        #  notSeen = true
        #end
        
        # fetches the source of the email for tmail to parse
        source  = imap.uid_fetch(uid, 'RFC822')
      
        if source == nil
          puts "Couldn't find mail with uid: #{uid}"
          next
        end
      
        source = source.first.attr['RFC822']
        
        email = TMail::Mail.parse(source)  
        
        if user == nil
          next
        end
       
        device = nil
      
        # If has attachments, save them
        if email.has_attachments?
          email.parts.each_with_index do |part, index|
            puts part.content_type
      
            # Text files are ignored. If mail has attachments, body was considerede as attachment.
            if part.content_type == "text/plain" or part.content_type == "multipart/alternative"
              next
            end
            
            # Create device if doesn't already exist
            if device == nil
              # Try to find virtual device or create it
              device = findOrCreateVirtualDevice(user.id, virtual_device_name)
              
              # If device name is already in use for other type of device, 
              if device == nil
                puts "Couldn't create virtual_container with name #{virtual_device_name}"
                next
              end
            end            
                    
            filename = part_filename(part)
            content_type = part.content_type
            filename ||= "#{index}.#{ext(part)}"
            file = filename
            fname = file.split(".")
                      
            # If prefix given in topic, add it to filename
            if email.subject.to_s.include?("[p]") 
              # Adds email topic as a prefix for the file
              filename = email.subject.to_s.gsub('[p]', '').strip.gsub(/\r/, '_') + "_" + filename
            end
           
            # Use virtualContainerManager to add the file
            # Create the manager      
            @virtualContainerManager = VirtualContainerManager.new(user, device.dev_name)
        
            # Add file with the manager
            @virtualContainerManager.addFile('/' + filename, part.body)
            
            # Add metadata
            @virtualContainerManager.addMetadata('/' + filename, "mail_topic", email.subject)
            @virtualContainerManager.addMetadata('/' + filename, "mail_from", email.from.to_s.strip)
            
            # Make the commit
            @virtualContainerManager.commit
            
            puts "File #{filename} was saved to visualrest"
          end
        end
        # If mail was not seen, mark it again as not seen
        #puts "merkitään lukemattomaksi"
        #if notSeen
        #  imap.store(uid, "-FLAGS", [:seen])
        #end
        if uid > new_uid
          new_uid = uid
        end
      end
    
    
      imap.logout
      imap.disconnect
 
    rescue => e
      puts "Problem fetching users mails"
      puts e
      return new_uid
    end
    return new_uid
  end
  
  def findOrCreateVirtualDevice(user_id, dev_name)
    device = Device.find_by_user_id_and_dev_name(user_id, dev_name)
    if device != nil
      if device.dev_type != "virtual_container"
        # Device with right name and wrong type was found
        return nil      
      end
    else
      # Device with requested name wasn't found, lets create it
      device = Device.create(:user_id => user_id,
                             :dev_name => dev_name,
                             :dev_type => "virtual_container",
                             :last_seen => DateTime.now,
                             :direct_access => false)
    end
    return device
  end
  
  
  def findUserAndContext(receiver)
    hash_i = receiver.index('+')
    hash_i_e = receiver.index('@')
    if hash_i == nil or hash_i_e == nil or hash_i >= hash_i_e
      return nil
    end
    hash = receiver[hash_i+1..hash_i_e-1].split('_')
  
    if hash.size != 2
      return nil
    end
    
    user = hash[0]
    context = hash[1]
    if user == nil or context == nil
      return nil
    end
    return user, context      
  end
  
  def part_filename(part)
            file_name = (part['content-location'] &&
            part['content-location'].body) ||
            part.sub_header("content-type", "name") ||
            part.sub_header("content-disposition", "filename")
  end
  
         
  def ext( mail )
    @@CTYPE_TO_EXT[mail.content_type] || 'txt'
  end

end

  def addContextRights(contextID, devf_id)
    begin
      if devf_id == nil
        return
      end
            
      # Adds same group rights to the devfile as context has
      groups = ContextGroupPermission.find_all_by_context_id(contextID)
            
      if groups
        groups.each do |cgp|
          DevfileAuthGroup.find_or_create_by_devfile_id_and_group_id(:devfile_id => devf_id,
                                                                     :group_id => cgp.group_id)
        end
      end
    rescue => e
      puts "Error in adding contextrights: #{e.to_s}"
    end
      
    return
  end

