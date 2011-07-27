require File.dirname(__FILE__) + '/../../../../../test/test_helper'
require 'scrums_controller'

class ScrumsController; def rescue_action(e) raise e end; end

class ScrumsControllerTest < Test::Unit::TestCase
  fixtures :projects, :users, :scrums
  
  def setup
    @controller = ScrumsController.new
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    @request.session[:user_id] = 2
    @scrum = Scrum.create(:task_done => "task done", :todo => "todo", :roadblocks => "roadblocks", 
                          :user_id => 2, :project_id => 1,
                          :report_on => "2008-08-08")
  end
  
  def test_index
    get :index, :id => "ecookbook"
    
    assert_response :success
    assert_template 'index'
    assert assigns(:users)
    assert assigns(:date)
  end
  
  def test_get_create
    get :create, :id => "ecookbook", :date => Date.today.to_s
    
    assert_response :success
    assert_template 'create'
    assert assigns(:scrum)
  end
  
  def test_post_create
    post :create, 
         :id => "ecookbook", :date => Date.today.to_s, 
         :scrum => {:task_done => "task done", :todo => "to do", :roadblocks => "roadblocks"}
         
    assert_equal Date.today, assigns(:scrum).report_on
    assert_equal projects(:projects_001), assigns(:scrum).project
    assert_equal User.current, assigns(:scrum).user
    scrum = Scrum.find(:first, :conditions => {:project_id => 1, :report_on => Date.today.to_s})
    assert_not_nil scrum
    assert_equal "task done", scrum.task_done
    assert_equal "to do", scrum.todo
    assert_equal "roadblocks", scrum.roadblocks
    assert_equal "Successful creation.", flash[:notice]
    assert_redirected_to :action => 'index'
  end
  
  def test_post_create_with_future_date
    post :create,
         :id => "ecookbook", :date => (Date.today+1).to_s,
         :scrum => {:task_done => "future task done", :todo => "future to do", :roadblocks => "future roadblocks"}
         
    assert_equal "Unsuccessful creation.", flash[:error]
    assert_redirected_to :action => 'index'
  end
  
  def test_get_update                 
    get :update, :id => 1, :date => "2008-08-08"
    
    assert_response :success
    assert_template 'update'
    assert assigns(:scrum)
    assert assigns(:date)
  end
  
  def test_post_update
    post :update, 
         :id => 1, 
         :date => "2008-08-08", 
         :scrum => {:task_done => "updated task done", :todo => "updated todo", :roadblocks => "updated roadblocks"}
    
    assert_equal "Successful update.", flash[:notice]
    assert_redirected_to :action => 'index'
  end
  
  def test_get_show
    get :show, 
        :id => 1,
        :year => 2008, :month => 8, :day => 8,
        :user_id => 2, 
        :report_on => "2008-08-08"
    
    assert_response :success
    assert_template '_show'
    assert assigns(:users)
    assert assigns(:scrum)
  end
  
  def test_get_delete
    get :delete, :id => 1, :date => "2008-08-08"
    
    assert_response :success
    assert_template 'delete'
    assert assigns(:scrum)
  end
  
  def test_post_delete
    post :delete, :id => 1, :date => "2008-08-08"
    
    assert_equal "Successful deletion.", flash[:notice]
    assert_redirected_to :action => 'index'
  end
  
end