require 'bcrypt'

class User < ActiveRecord::Base

  # This is used as an easier way of accessing who is the current user
  def User.current=(u)
    Thread.current[:user] = u
  end
  
  def User.current
    Thread.current[:user]
  end
  
  def User.search(search_term)
    return [] unless search_term && !search_term.empty?
    User.find_public(:all, :conditions => ["(name LIKE :search OR affiliation LIKE :search OR email LIKE :search)",{:search => "%#{search_term.strip}%"}], :order => 'name ASC' )
  end
  
  def User.find_public(*args)
    User.with_scope :find => { :conditions => ["ex_directory = 0"] } do
      User.find(*args)
    end
  end
  
  def User.sort_field; 'name_in_sort_order' end
  
  def User.find_or_create_by_crsid( crsid )
    user = User.find_by_crsid crsid
    return user if user
    # No email, so create
    user = InstallationHelper.CURRENT_INSTALLATION.local_user_from_id(crsid)
    return user
  end
  
  # Lists that the user is mailed about
  has_many :email_subscriptions
  
  # Lists that this user manages
  has_many :list_users
  has_many :lists, :through => :list_users
  
  # Talks that this user speaks on
  has_many :talks, :foreign_key => 'speaker_id', :order => 'start_time DESC'
  
  # Talks that this user organises
  has_many :talks_organised, :class_name => "Talk", :foreign_key => 'organiser_id', :conditions => "ex_directory != 1", :order => 'start_time DESC'

  validates_uniqueness_of :email, :message => 'address is already registered on the system'
    
  # Life cycle actions
  before_save :update_crsid_from_email
  before_save :update_name_in_sort_order
  before_create :create_password_reset_key
  after_create :create_personal_list
  after_create :send_password_reset_request

  # For encrypting the password in the db
  before_save :hash_password
  
  def hash_password
    if not self.password.nil?
      write_attribute(:hashed_password, BCrypt::Password.create(self.password))
    end
  end

  def authenticate(password)
    logger.error "XXXXXXX"
    logger.error password
    logger.error self.hashed_password
    logger.error BCrypt::Password.new(self.hashed_password)
    logger.error BCrypt::Password.new(self.hashed_password).is_password? password
    if not self.hashed_password.nil? and BCrypt::Password.new(self.hashed_password).is_password? password
      return true
    else
      return false
    end
  end

  def self.authenticate(email, password)
    user = find_by_email(email)
    if user
      if user.authenticate(password)
        return user
      end
    end
    return nil
  end

  # Try and prevent xss attacks
  include PreventScriptAttacks
  include CleanUtf # To try and prevent any malformed utf getting in
  
  # Has a connected image
  include BelongsToImage
  
  def editable?
    return false unless User.current
    ( User.current == self ) or ( User.current.administrator? )
  end
  
  def update_crsid_from_email
    return unless email =~ /^([a-z0-9]+)@cam.ac.uk$/i
    self.crsid = $1
  end
  
  def update_name_in_sort_order
    if name =~ /^\s*((.*) )?(.*)\s*$/
      self.name_in_sort_order = $2 ? "#{$3}, #{$2}" : $3
    else
      self.name_in_sort_order = ""
    end
  end

  def self.update_ex_directory_status
    User.find(:all).each { |u| u.update_ex_directory_status }
  end
  
  def update_ex_directory_status
    new_status = lists.find(:all,:conditions => ['ex_directory = 0']).empty? && talks.empty? && talks_organised.empty?
    update_attribute(:ex_directory,new_status) unless self.ex_directory? == new_status
    new_status
  end
  
  attr_accessor :password
  
  def generate_random_chars(size = 10)
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    new_stuff = ""
    1.upto(size) { |i| new_stuff << chars[rand(chars.size-1)] }
    return new_stuff
  end

  # ten digit password
  #def randomize_password( size = 10 )
  #  write_attribute(:password, generate_random_chars(size))
  #end
  
  # After creating a user, create their personal list
  def create_personal_list
    list_name = 
      if self.name; "#{self.name}'s list"
      elsif self.crsid; "#{self.crsid}'s list"
      else; "Your personal list"
    end
    list = List.create! :name => list_name, :details => "A personal list of talks.", :ex_directory => true
    self.lists << list
  end
  
  # Do we send this user emails, in general (?)
  attr_accessor :send_email

#  def send_password_if_required
#    send_password if send_email
#  end

  def create_password_reset_key
    write_attribute(:password_reset_key, generate_random_chars(size=20))
  end
  
  def send_password_reset_request
    email = Mailer.create_password_reset(self)
    Mailer.deliver email
  end

#  def send_password
#    email = Mailer.create_password( self )
#    Mailer.deliver email
#  end
  
  def personal_list
    lists.first
  end
  
  def only_personal_list?
    (lists.size == 1)
  end
  
  def send_emails_about_personal_list
    EmailSubscription.find_by_list_id_and_user_id( personal_list, id ) ? true : false
  end
  
  def send_emails_about_personal_list=(send_email)
    if send_email == '1' && !send_emails_about_personal_list
      email_subscriptions.create :list => personal_list
    elsif send_email == '0' && send_emails_about_personal_list
      EmailSubscription.find_by_list_id_and_user_id( personal_list, id ).destroy
    end
  end
  
  # Subscribe by email to a lsit
  def subscribe_to_list( list )
    email_subscriptions.create :list => list
  end
  
  def has_added_to_list?( thing )
    case thing
    when List
      lists.detect { |users_list| users_list.children.direct.include?( thing ) }
    when Talk
      lists.detect { |users_list| users_list.talks.direct.include?( thing )}
    end
  end
  
  # This is used upon login to check whether the user should be asked to fill in more detail
  def needs_an_edit?
    return last_login ? false : true
  end
  
end
