class StatisticsController < ApplicationController

before_filter :ensure_user_is_logged_in, :except => %w{ index current_series current_lists}
  
  def index
    # Users
    @number_of_users = User.count
    @number_of_recent_users = User.count :conditions => ['last_login > ?',1.month.ago]
    
    # Talks
    @number_of_talks = Talk.count
    @number_of_past_talks = Talk.count :conditions => ['start_time < ?',Time.now]
    @number_of_future_talks = Talk.count :conditions => ['start_time >= ?',Time.now]
    
    # Lists
    @number_of_lists = List.count
    @number_of_user_favourites = User.count
    @number_of_venues = Venue.count
    @number_of_series = Talk.count_by_sql "select count(distinct series_id) from talks"
    @number_of_listings = @number_of_lists - @number_of_user_favourites - @number_of_venues - @number_of_series
  end
  
  def current_series
    @current_series_count = Talk.count_by_sql ['select count(distinct series_id) from talks where start_time >= ?', Time.now]
    @current_series = List.find_by_sql ['select distinct lists.* from lists, talks where (lists.id = talks.series_id) and talks.start_time >=?', Time.now]
    @current_talks = Talk.find_public(:all, :conditions => ['start_time >= ?',Time.now])
     
  end
  
  def current_managers
    @current_managers = Talk.find_public(:all, :conditions => ['start_time >= ?',Time.now])
    
  end
  
  def current_lists
    @current_lists = Talk.find_public(:all, :conditions => ['start_time >= ?',Time.now])
    
  end
  
  
end
