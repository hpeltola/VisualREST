require 'rubygems'
require 'yaml'
require 'xml/libxml'
require 'net/http'
require "date"
require "uri"
require 'rexml/document'



@@locations_metafile = '.locations_metafile'



class Location
  
  
  def initialize(locationMode)
    @@locationMode = locationMode
    puts @@locationMode
    
    @@currentLocation = {'latitude' => 0, 'longitude' => 0}
    @@currentLocationUpdated = nil  
    
    if @@locationMode == 'GPS'
      Thread.start{
        io = IO.popen("/usr/libexec/navicore-gpsd-helper >> .vrGPSTrace")
        
        #b = bb.readlines
        #puts b.join
      }
      
    end
    
    
  end
  
  
  def getLocation
    
    if @@currentLocation == nil or @@currentLocationUpdated == nil or (DateTime.now.min() - @@currentLocationUpdated.min()) > 2
      updateLocation
      @@currentLocationUpdated = DateTime.now
    end
    
    return @@currentLocation
    
  end
  
  
  
  # Updates current location of the device
  def updateLocation
    if @@locationMode == 'GPS'
      @@currentLocation = getLocationFromGPSfile
    elsif @@locationMode == 'noGPS1'
      @@currentLocation = getLocationFromService1
    else
      @@currentLocation = getLocationFromService2    
    end  
    
    # If updating from one service failed, tries updating from the other service
    if @@currentLocation['latitude'] == 0 or @@currentLocation['longitude'] == 0
      if @@locationMode == 'noGPS1'
        @@currentLocation = getLocationFromService2
      else
        @@currentLocation = getLocationFromService1  
      end
    end
  end
  
  # Gets location based on the ip address from the service: http://api.hostip.info/
  def getLocationFromService1
    puts "service 1"
    location_longitude = 0 
    location_latitude = 0 
    location = {'latitude' => location_latitude, 'longitude' => location_longitude}
    begin 
      
      uri = URI.parse('http://api.hostip.info/')
      Net::HTTP.start(uri.host, 80) { |http|
        
        response = http.get(uri.path.size > 0 ? uri.path : "/")
        case response
          when Net::HTTPSuccess
          xml = response.body
          
          if xml != nil
            puts "testx1"
            doc, posts = REXML::Document.new(xml), []  
            doc.elements.each('HostipLookupResultSet/gml:featureMember/Hostip/ipLocation/gml:pointProperty/gml:Point/gml:coordinates') do |p|
              location_longitude, location_latitude = p.text.to_s.split(',')
              location = {'latitude' => location_latitude.to_f, 'longitude' => location_longitude.to_f}
            puts "testx2"
            end  
          end
          
        else
          return errorLocation
        end
      }
      
    rescue => e
      puts "Couldn't update location: " + e.to_s
      return errorLocation
    end
    
    puts "Location from service1: " + location['latitude'].to_s + ", " + location['longitude'].to_s
    return location
  end
  
  
  
  # Gets location based on the ip address from service: ipaddressgeolocation.com 
  def getLocationFromService2
    
    location_longitude = 0 
    location_latitude = 0 
    location = {'latitude' => location_latitude, 'longitude' => location_longitude}
    begin 
      
      uri = URI.parse('http://www.ipaddressgeolocation.com')
      
      Net::HTTP.start(uri.host, 80) { |http|
        
        response = http.get(uri.path.size > 0 ? uri.path : "/")
        
        case response
          when Net::HTTPSuccess
          
            response.body.split(%r{<tr\s*>(.*?)</tr\s*>}mi).each do |tr|
              if tr['My IP address latitude:'] 
                location['latitude'] = (tr.split(%r{<td\s*>(.*?)&deg;</td\s*>}mi)[1]).to_f
              elsif tr['My IP address longitude:']
                location['longitude'] = (tr.split(%r{<td\s*>(.*?)&deg;</td\s*>}mi)[1]).to_f
              end
            end

          else

            return errorLocation
          end 
      }
    rescue => e
      puts "Couldn't update location: " + e.to_s
      location = errorLocation
    end


    # Tällä voi antaa testiarvoja krs: 62.267423, 21.365082, koti: 61.454583, 23.842349
    # krs
    #location = {'latitude' => 62.267423, 'longitude' => 21.365082}
    # koti: 
    # location = {'latitude' => 61.454583, 'longitude' => 23.842349}
    puts "Location from service2: " + location['latitude'].to_s + ", " + location['longitude'].to_s
    return location
  end
  
  

  def errorLocation
    location = Hash.new
    location['latitude'] = 0
    location['longitude'] = 0
    puts "Couldn't update location. Location: " + location['latitude'].to_s + ", " + location['longitude'].to_s
    return location
  end

  
  
  def getLocationFromGPSfile
    
    location = {'latitude' => 0, 'longitude' => 0}
    
    begin 

      File.open(".vrGPSTrace", "r") do |infile|
        while (line = infile.gets)
          if line['$GPGLL'] != nil
            data = line.split(',', 5)
            
            lat = data[1].to_s
            lon = data[3].to_s
            
            if !lat.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) or !lon.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/)
              next
            else

            lat = (data[1].to_f)/100
            lon = (data[3].to_f)/100
            
              #puts "lati: " + lat.to_s
              #puts "longi: " + lon.to_s
              puts line
              location = {'latitude' => 61.449820, 'longitude' => 23.857239 }
            end
          end
        end
      end

      if !location['latitude'].to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) or !location['longitude'].to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/)
        raise Exception.new("Can't get location.")
      end
      
      @@currentLocation = location
      
    rescue => e
      puts e
      @@currentLocation = {'latitude' => 0, 'longitude' => 0}
    end
  end
  
  



end



