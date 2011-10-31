class CollageHelper

  include Magick

  
  
  
  def initialize(thumbnail_paths, thumbnail_full_path)
    begin
      @template_path = 'public/thumbnails/clusters/template.png'
      @slide_path = 'public/thumbnails/clusters/slide.png'
      @no_pic = 'public/thumbnails/vR_no_picture_2.png'
  
      @@max_rotation = 25.0
      
      # In this example I have 7 images labled 1.png..7.png 
      # The following loop picks 4 random images from the 7
      # 1 for the main image and 3 for the slides
      images = Array.new
      thumbnail_paths.each do |path|
        #break if images.include? path # make sure the picked images are unique before adding to images array
        images << path
      end
  
      
      width = 180
      height = 180
      
      max_num = 25.0
      tscale = 0.05
      
      #puts "NUM OF IMAGES: #{images.count.to_s}"
      sqrt_num = Math.sqrt(images.count)
      per_row = sqrt_num.ceil
      #puts "PER ROW: #{per_row.to_s}"
      
      rows_count = (Float(images.count) / Float(per_row)).ceil
      #puts "ROWS COUNT: #{rows_count.to_s}"
      
      tscale = images.count == 1 ? 0.7 : 0.95
      @thumb_width = (width / per_row) * tscale
      @thumb_height = (height / per_row) * tscale


      wcenter = 0.0 * @thumb_width
      hcenter = 0      
      if rows_count != sqrt_num and rows_count != per_row
        hcenter = 0.5 * @thumb_height
      end

      #template = Image.new(width, height) { self.background_color = '#87a5ff' }
      template = Image.new(width, height) { self.background_color = 'transparent' }
      
      j = -1
      i = 0 # column cursor
      k = 0 # row cursor
      images.each do |img|
        slide = create_slide(img)
        if not slide
          puts "skipping slide: #{img.to_s}"          
          next
        end

        if i.modulo(per_row) == 0
          j += 1
          i = 0
          k += 1
        end
        
        
        h_correct = 15.0 # if only 1 image
        w_correct = 15.0 # if only 1 image
        if images.count > 1
          w_correct = @thumb_width * 0.1
          if i + 1 > Float(per_row) / 2.0
            w_correct *= -1.0
          end
          h_correct = @thumb_height * 0.1
          if k > Float(rows_count) / 2.0
            h_correct *= -1.0
          end
        end

        template.composite!(slide, i * @thumb_width + wcenter + w_correct, j * @thumb_height + hcenter + h_correct, OverCompositeOp)
        i += 1
      end
  
      
      
      @thumbnail_full_path = thumbnail_full_path
        
      # save finished collage
      template.write(@thumbnail_full_path)
    rescue Exception => ee
      puts ee.to_s
      return ""
    end
  end
  
  
  
  def backandforth(degree)
    polarity = rand(2) * -1
    return rand(degree) * polarity if polarity < 0
    return rand(degree)
  end
  

  def create_slide(image)
    
    begin
    
      slide = Image.read(@slide_path).first
      slide_background = Image.new(slide.columns, slide.rows) { self.background_color = 'transparent' }
      
      begin
        photo = Image.read(image).first
        if not photo then raise Exception.new("Could not load thumb") end
      rescue Exception => e
        puts e.to_s
        puts "No thumb for: #{image.to_s}"
        photo = Image.read(@no_pic).first
      end
      # create a grey scale gradient fill for our mask
      mask_fill = GradientFill.new(0, 0, 0, 88, '#FFFFFF', '#F0F0F0')
      mask = Image.new(photo.columns, photo.rows, mask_fill)
  
      # create thumbnail sized square image of photo
      photo.crop_resized!(88,88)
    
      # apply alpha mask to slide
      photo.matte = true
      mask.matte = false
      photo.composite!(mask, 0, 0, CopyOpacityCompositeOp)
      
      # composite photo and slide on transparent background
      slide_background.composite!(photo, 16, 16, OverCompositeOp)
      slide_background.composite!(slide, 0, 0, OverCompositeOp)
      
      
      # Resize:
  #puts "thumb size, w: " + @thumb_width.to_s + "  h: " + @thumb_height.to_s
      slide_background = slide_background.adaptive_resize(@thumb_width, @thumb_height)
      
      
      # rotate slide +/- 45 degrees
      rotation = backandforth(@@max_rotation)
      slide_background.rotate!(rotation)
      
      # create workspace to apply shadow
      workspace = Image.new(slide_background.columns+5, slide_background.rows+5) { self.background_color = 'transparent' }
      shadow = slide_background.shadow(0, 0, 0.0, '20%')
      workspace.composite!(shadow, 3, 3, OverCompositeOp)
      workspace.composite!(slide_background, NorthWestGravity, OverCompositeOp)
      
      return workspace
    rescue Exception => ee
      puts ee.to_s
      return nil
    end 
  end


  def get_thumbnail_path
    return @thumbnail_full_path
  end
  
  
  
  
  
end