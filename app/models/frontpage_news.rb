class FrontpageNews < ActiveRecord::Base
  belongs_to :user
  MESSAGEBOX_COLS = 70
  MESSAGEBOX_ROWS = 5
  
  NEWS_MIN_LENGTH = 5
  
  
end
