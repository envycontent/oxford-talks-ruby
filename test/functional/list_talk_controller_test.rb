require File.dirname(__FILE__) + '/../test_helper'
require 'list_talk_controller'

# Re-raise errors caught by the controller.
class ListTalkController; def rescue_action(e) raise e end; end

class ListTalkControllerTest < ActionController::TestCase
  
  fixtures :lists, :list_users, :users, :list_talks, :talks
  
  def setup
    @controller = ListTalkController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_routes
    with_options :controller => 'list_talk' do |test|
      test.assert_routing '/include/talk', :action => 'create'
      test.assert_routing '/include/talk/destroy/1', :action => 'destroy', :id => '1'
    end
  end

  def test_must_be_logged_in_to_edit
    get :edit, :list_id => lists(:series).id
    assert_redirect_to_login
  end
  
  def test_must_be_manager_to_edit
    get_as_user :vic, :edit, :list_id => lists(:series).id
    assert_permission_denied
  end
  
  def test_edit
    get_as_user :seriesowner, :edit, :list_id => lists(:series).id
    assert list = assigns(:list)
    assert_equal lists(:series), list
    assert_kind_of Array, assigns(:list_talks)
    assert_response :success
  end
  
  def test_destroy_from_edit_screen
    list_talk = ListTalk.create! :list => lists(:series), :talk => talks(:one)
    get_as_user :seriesowner, :destroy, :id => list_talk.id, :return_to_edit => '1'
    assert_redirected_to include_talk_url(:list_id => lists(:series).id, :action => 'edit')
  end
  
  def list
    lists(:vicslist)
  end

  def child
    talks(:one)
  end

  def owner
    users(:vic)
  end
  
  def not_owner
    users(:jim)
  end
  
  def administrator
    users(:administrator)
  end
  
  def list_talk
    ListTalk.create :list => list, :talk => child
  end
  
  def test_must_be_a_user
    get :create, { :child => child.id }
    assert_response :redirect
    assert_redirected_to login_url
    put :create, { :child => child.id }
    assert_response :redirect
    assert_redirected_to login_url
    get :destory, { :child => child.id }
    assert_response :redirect
    assert_redirected_to login_url
  end
  
  def test_must_be_authorized
    post :create, { :child => child.id, :add_to_list => { list.id => 'add' } }, {:user_id => not_owner.id }
    assert_response 401
    post :create, { :child => child.id, :add_to_list => { list.id => 'remove' } }, {:user_id => not_owner.id }
    assert_response 401
    get :destroy, { :id => list_talk.id }, {:user_id => not_owner.id }
    assert_response 401
    post :destroy, { :id => list_talk.id }, {:user_id => not_owner.id }
    assert_response 401  
  end
  
  def test_instant_create
    assert_equal 0, list.list_talks.direct.size
    assert_equal 1, owner.lists.size
    assert_equal true, owner.only_personal_list?
    get :create, { :child => child.id }, {:user_id => owner.id }
    assert_equal 1, list.list_talks.direct.size
    assert_response :redirect
    assert_redirected_to talk_url(:id => child )
  end
  
  def test_instant_destroy
    soon_to_be_doomed = list_talk
    assert_equal 1, list.list_talks.direct.size
    assert_equal 1, owner.lists.size
    assert_equal true, owner.only_personal_list?
    get :destroy, { :child => child.id }, {:user_id => owner.id }
    assert_equal false, list.list_talks.direct.include?( soon_to_be_doomed )
    assert_response :redirect
    assert_redirected_to talk_url(:id => soon_to_be_doomed.talk_id )
  end
  
  def test_multiple_create_and_destroy
    # Give the owner  a second list ot manage
    second_list = List.create :name => 'second list'
    second_list.managers << owner
    third_list = List.create :name => 'third list'
    third_list.managers << owner
    assert_equal false, owner.only_personal_list?
     
    # In stead of adding to personal list, will now be 
    # presented with a list of the lists the user managers 
    # and asked to select a list
     
    get :create, { :child => child.id }, {:user_id => owner.id }
    assert_equal owner.lists, assigns(:lists)
    assert_equal child, assigns(:child)
    assert_response :success
    assert_template 'create'
    assert_equal 0, list.list_talks.direct.size
    assert_equal 0, second_list.list_talks.direct.size
    
    # User then specifies what lists to add to, and submits:
 
    post :create, { :child => child.id, :add_to_list => { list.id => 'add', second_list.id => 'add', third_list.id => ''} }, {:user_id => owner.id }
    assert_equal 1, list.list_talks.direct.size
    assert_equal 1, second_list.list_talks.direct.size
    assert_response :redirect
    assert_redirected_to talk_url(:id => child.id)
 
    # Now when trying to destroy will get asked to come back
    get :destroy, { :child => child.id }, {:user_id => owner.id }
    assert_response :redirect
    assert_redirected_to include_list_url(:action => 'create', :child => child.id)
    assert_equal 1, list.list_talks.direct.size
    assert_equal 1, second_list.list_talks.direct.size
    
    # Now try deleting a couple
    post :create, { :child => child.id, :add_to_list => { list.id => 'remove', second_list.id => 'remove', third_list.id => ''} }, {:user_id => owner.id }
    assert_equal 0, list.list_talks.direct.size
    assert_equal 0, second_list.list_talks.direct.size
    assert_response :redirect
    assert_redirected_to talk_url(:id => child.id)
 
    # Now try a mixed picture, including one that is invalid
    post :create, { :child => child.id, :add_to_list => { list.id => 'add', second_list.id => 'remove', third_list.id => 'add'} }, {:user_id => owner.id }
    assert_equal 1, list.list_talks.direct.size
    assert_equal 0, second_list.list_talks.direct.size
    assert_equal 1, third_list.list_talks.direct.size
    assert_response :redirect
    assert_redirected_to talk_url(:id => child.id)
 
    post :create, { :child => child.id, :add_to_list => { list.id => 'remove', second_list.id => 'add', third_list.id => ''} }, {:user_id => owner.id }
    assert_equal 0, list.list_talks.direct.size
    assert_equal 1, second_list.list_talks.direct.size
    assert_equal 1, third_list.list_talks.direct.size
    assert_response :redirect
    assert_redirected_to talk_url(:id => child.id)    
  end
  
  def test_cannot_repeatedly_add_the_same_talk
     assert_equal true, owner.only_personal_list?
     get :create, { :child => child.id }, {:user_id => owner.id }
     get :create, { :child => child.id }, {:user_id => owner.id }
     get :create, { :child => child.id }, {:user_id => owner.id }
     assert_equal 1, list.list_talks.direct.size
     
     # Give the owner  a second list ot manage
     second_list = List.create :name => 'second list'
     second_list.managers << owner
     owner.reload
     assert_equal false, owner.only_personal_list?
     post :create, { :child => child.id, :add_to_list => { list.id => 'add'} }, {:user_id => owner.id }
     post :create, { :child => child.id, :add_to_list => { list.id => 'add'} }, {:user_id => owner.id }
     post :create, { :child => child.id, :add_to_list => { list.id => 'add'} }, {:user_id => owner.id }
     assert_equal 1, list.list_talks.direct.size
  end
  
  def test_destroy_specific_link
    soon_to_be_doomed = list_talk
    assert_equal true, list.list_talks.direct.include?( soon_to_be_doomed )
    get :destroy, { :id => soon_to_be_doomed.id }, {:user_id => owner.id }
    assert_equal false, list.list_talks.direct.include?( soon_to_be_doomed )
    assert_response :redirect
    assert_redirected_to talk_url(:id => soon_to_be_doomed.talk_id )
  end
  
  def test_cannot_remove_talk_from_series
    post :create, {:child => talks(:with_series).id, :add_to_list => { lists(:series).id => 'remove'}}, {:user_id => users(:seriesowner).id}
    assert_response :redirect
    assert_equal "Cannot remove &#145;Talk four with series&#146; from its series. ", flash[:warning]
  end
  
  private

   def post_as_user( user, action, parameters = {} )
     do_as_user :post, user, action, parameters
   end

   def get_as_user( user, action, parameters = {} )
     do_as_user :get, user, action, parameters
   end

   def do_as_user(request_type, user, action, parameters = {} )
     send( request_type, action, parameters, {:user_id => users(user).id } )
   end

   def assert_redirect_to_login
     assert_response :redirect
     assert_redirected_to login_url
   end

   def assert_permission_denied
     assert_response 401
   end
    
end
