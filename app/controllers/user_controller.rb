class UserController < ApplicationController
  before_filter :ensure_user_is_logged_in, :except => %w( new show create password_reset_sent reset_password update_password )
  before_filter :find_user, :except => %w( new create password_reset_sent )
  before_filter :check_can_edit_user, :except => %w( new show create index password_reset_sent reset_password update_password )
  
  # Filters
  
  def find_user
    @user = User.find params[:id]
  end
  
  def check_can_edit_user
    return true if @user.editable?
    flash[:error] = "You do not have permission to edit &#145;#{@user.name}}&#146;"
    render :text => "Permission denied", :status => 401
    false
  end
  
  # Actions
  
  def show
    @show_message = session['return_to'] ? true : false
  end
  
  def edit
    @show_message = session['return_to'] ? true : false
  end
  
  def create
    @user = User.new(params[:user])
    
    if @user.save
      flash[:confirm] = 'A new account has been created.'
      redirect_to :action => 'password_reset_sent'
    else
      render :action => 'new'
    end
  end

  def reset_password
    password_reset_key = params[:password_reset_key]
    if @user.password_reset_key != password_reset_key
      flash[:confirm] = 'Your password reset key was invalid'
      render :action => 'change_password'
    else
      @password_reset_key = password_reset_key
      render :action => 'change_password'
    end
  end

  def update_password
    reset_key = params[:password_reset_key]
    old_password = params[:existing_password]

    if not old_password.nil? and not @user.authenticate(old_password)
      flash[:confirm] = 'Your old password was incorrect'
      render :action => 'change_password'
    elsif not reset_key.nil? and @user.password_reset_key != password_reset_key
      flash[:confirm] = 'Your password reset key was invalid'
      render :action => 'reset_password_request'
    else
      if params[:new_password] != params[:new_password_confirmation]
        flash[:confirm] = 'The two versions of your new password did not match'
        render :action => 'change_password'
      else
        @user.password = params[:new_password]
        @user.password_reset_key = nil
        @user.save
        flash[:confirm] = 'Your password was updated'
        redirect_to login_path :action => 'other_users'
      end
    end
  end

  def update    
    if @user.update_attributes(params[:user])
      flash[:confirm] = 'Saved.'
      redirect_to user_url(:id => @user.id)
    else
      render :action => 'edit'
    end
  end
end
