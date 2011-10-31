class DeleteHelper
  
  
  def initialize(deviceid, printM = false)
    
    
    @device = Device.find_by_id(deviceid)
    
    if not @device
      raise Exception.new("Device: #{deviceid.to_s} not found!")
    end
    
    
    @printMessages = printM
    
  end
  


  #
  # Removes: clears db, removes .git and essence, and thumbnails
  # Does not remove the device itself!
  def removeContent
       
    # Vaihe 0: UserDropboxContent
    
    begin
      # dropbox content
      udcs = UserDropboxContent.find(:all, :conditions => ["device_id = ? ", @device.id])
      udcs.each do |udc|
        putsP "poistetaan udc"
        udc.delete
      end
    rescue Exception => e
      putsE(e)
    end
    
   
    # Vaihe 1: commits + blobs_in_commits
    
    commits = Commit.find(:all, :conditions => ["device_id = ? ", @device.id])
    
    begin
      commits.each do |com|
        b_in_coms = BlobsInCommit.find(:all, :conditions => ["commit_id = ? ", com.id])
        b_in_coms.each do |bic|
          putsP "poistetaan bic"
          BlobsInCommit.delete_all(["commit_id = ? AND blob_id = ?", bic.commit_id.to_s, bic.blob_id.to_s])
        end
        putsP "poistetaan com"
      end
    rescue Exception => e
      putsE(e)
    end
    
    
    
      
    # Vaihe 2: devfilet + blobs + metadatas + file_observers + filelocations
    
    devfiles = Devfile.find(:all, :conditions => ["device_id = ? ", @device.id])
    devfiles.each do |df|
      
      begin
        # Blobit
        blobs = Blob.find(:all, :conditions => ["devfile_id = ? ", df.id])
        blobs.each do |b|
          putsP "poistetaan blob"
          b.delete
        end
      rescue Exception => e
        putsE(e)
      end
      
      begin
        # Metadatas
        metadatas = Metadata.find(:all, :conditions => ["devfile_id = ? ", df.id])
        metadatas.each do |md|
          putsP "poistetaan md"
          md.delete
        end
      rescue Exception => e
        putsE(e)
      end
      
      
      begin
        # file_observers
        fileobs = FileObserver.find(:all, :conditions => ["devfile_id = ? ", df.id])
        fileobs.each do |fo|
          putsP "poistetaan fo"
          fo.delete
        end
      rescue Exception => e
        putsE(e)
      end
      
      begin
        filelocs = Filelocation.find(:all, :conditions => ["devfile_id = ? ", df.id])
        if filelocs != nil
          filelocs.each do |fl|
            putsP "poistetaan fl"
            fl.delete
          end
        end
      rescue Exception => e
        putsE(e)
      end
      
      # Devfile
      putsP "Poistetaan devfile"
      df.delete 
    end
    
    # Removes also the essence
    removeEssence
    removeThumbnails
    
    @device.update_attribute(:commit_id, nil)
    return
  end


  def removeEssence
    begin
      
      # Deletes also the essence from folders and .git repo
      if @device.dev_type == "virtual_container"
        # if device was virtual container, deletes .git folder and files
        path = "private/#{@device.id.to_s}/"
      else
        # Deletes uploaded essence
        path = "public/devfiles/#{@device.id.to_s}/"
      end
      FileUtils.rm_rf(path)
      puts "Essence removed!"
    rescue Exception => e
      putsE(e)
    end
  end

  def removeThumbnails
    begin
      # Deletes thumbnails
      thumb_dir = "public/thumbnails/" + @device.id.to_s + "/"
      if File.directory?(thumb_dir)
        puts "Deleting thumbnail..."
        FileUtils.rm_rf(thumb_dir)
        puts "Thumbnails deleted..."
      end
    rescue Exception => ex
      putsE(ex)
    end
  end



  #
  # Removes: removeContent + XMPP-account + device from db
  #
  def removeDevice
    # Removes the files first
    begin
      removeContent
    rescue Exception => e
      putsE(e)
    end
    
    deleteXMPPAccount
    # These are already removed by removeContent -method
    #removeThumbnails
    #removeEssence
    
    @device.delete
    return
  end





  private
  
  
  
  
  
  def deleteXMPPAccount
    
    if @device.xmppname == nil or @device.xmpppasswd == nil or @device.xmppname.empty? or @device.xmpppasswd.empty?
      puts "No XMPP account"
      return
    else
      puts "Deleting XMPP account"
    end
    
    # Deletes Jabber account and if deletion fails doesnt delete device from db
    i = 0
    begin
      puts "Deleting xmpp account.."
      cl = Jabber::Client.new(Jabber::JID.new(@device.xmppname))
      cl.connect
      cl.auth(@device.xmpppasswd)
      cl.remove_registration
      cl.close
      puts "xmpp account deleted.."
    rescue => e
      puts "Error in deleting xmpp account:" + e
      if i < 4
        i += 1
        puts "Retrying to delete xmpp account"
        retry
      else
        puts "Couldn't delete xmpp account"  
        return false
      end    
    end
    return true
  end
  
  
  
  
  
  
  
  def putsP(s)
    if @printMessages
      puts s
    end
  end
  
  def putsE(e)
    puts "DeleteHelper Error: #{e.to_s}"
    puts "  -- line: #{e.backtrace[0].to_s}"
  end




end