class ScrumsController < ApplicationController
  unloadable
  layout 'base'
  
  helper :scrums
  
  before_filter :find_project,:except=>[:project_members,:show_list, :popup, :pager]
  before_filter :authorize,:except=>[:project_members,:show_list, :popup, :pager]
  before_filter :is_member?, :only=>[:create, :update, :delete]

  def index
    @date = Time.now
    @users = @project.members.map(&:user).sort
    
    render :action=>:index
  end
  
  def create
    @scrum = Scrum.new
    if User.current.submitted_scrum_for?(@project, params[:date])
      redirect_to :controller => :scrums, :action => :update, :id => params[:id], :date => params[:date]
    end
    if request.post?
      @date = params[:date].split('-')
      @scrum.attributes = params[:scrum]
      @scrum.user = User.current
      @scrum.project = @project
      @scrum.report_on = params[:date].nil? ? Date.today : Date.new(@date[0].to_i,@date[1].to_i,@date[2].to_i)
      if @scrum.report_on > Date.today
        flash[:error] = 'Unsuccessful creation.'
        redirect_to :controller => :scrums, :action => :index, :id => params[:id]
      else
        if @scrum.save
          flash[:notice] = 'Successful creation.'
          redirect_to :controller => :scrums, :action=>:index, :id => params[:id]
        end
      end
    end
  end
  
  def update
    @date = params[:date].split('-')
    report_on = params[:date].nil? ? Date.today : Date.new(@date[0].to_i,@date[1].to_i,@date[2].to_i)
    @scrum = Scrum.get_scrum_for(@project.id, report_on)
    if request.post? 
      @scrum.user = User.current
      @scrum.project = @project
      @scrum.report_on = report_on
      if @scrum.update_attributes(params[:scrum])
        flash[:notice] = 'Successful update.'
        redirect_to :controller => :scrums, :action=>:index, :id => params[:id]
      end 
    end
  end
  
  def show
    id = params[:user_id]
    report_on = params[:report_on]
    @users = @project.members.map(&:user).sort
    @scrum = Scrum.get_scrum_for(@project.id, report_on, id)
    render :partial=>"show"
  end

  def delete
    @scrum = Scrum.get_scrum_for(@project.id, params[:date])
    if request.post?
      if @scrum.destroy
        flash[:notice] = 'Successful deletion.'
      end
      redirect_to :controller => :scrums, :action => :index, :id => params[:id]
    end
  end
  
  def preview
    @scrumtext = params[:scrum]
    render :partial => 'preview'
  end

  def project_members
    @project = Project.find(params[:project_id])
    @project_members = @project.assignable_users
    render :partial=> 'project_members', :locals => {:project_members => @project_members}
  end

  def show_list 
    @free_period = false
    @scrum_date_from = @scrum_date_to = nil
    @user = User.current
    @projects_by_manager = @user.manager_role_for_project(@user.projects).sort    
    @project_members = @projects_by_manager[0].assignable_users     
    
    if params[:scrum_period_type] == '1'
      case params[:scrum_period].to_s
      when 'today'
        @scrum_date_from = @scrum_date_to = Date.today
      when 'yesterday'
        @scrum_date_from = @scrum_date_to = Date.today - 1
      when 'current_week'
        @scrum_date_from = Date.today - (Date.today.cwday - 1)%7
        @scrum_date_to = @scrum_date_from + 6
      when 'last_week'
        @scrum_date_from = Date.today - 7 - (Date.today.cwday - 1)%7
        @scrum_date_to = @scrum_date_from + 6
      when '7_days'
        @scrum_date_from = Date.today - 7
        @scrum_date_to = Date.today
      when 'current_month'
        @scrum_date_from = Date.civil(Date.today.year, Date.today.month, 1)
        @scrum_date_to = (@scrum_date_from >> 1) - 1
      when 'last_month'
        @scrum_date_from = Date.civil(Date.today.year, Date.today.month, 1) << 1
        @scrum_date_to = (@scrum_date_from >> 1) - 1
      when '30_days'
        @scrum_date_from = Date.today - 30
        @scrum_date_to = Date.today
      when 'current_year'
        @scrum_date_from = Date.civil(Date.today.year, 1, 1)
        @scrum_date_to = Date.civil(Date.today.year, 12, 31)
      end 
    elsif params[:scrum_period_type] == '2'
      @scrum_date_from = params[:scrum_date_from] 
      @scrum_date_to = params[:scrum_date_to]
      @free_period = true
    end
    
    @scrum_date_from, @scrum_date_to = @scrum_date_to, @scrum_date_from if @scrum_date_from > @scrum_date_to
    
    user_id = params[:owner_select]
    project_id = params[:project_select]
    cond = "project_id = #{project_id}"
    cond << " AND user_id = #{user_id}" if !user_id.eql?('all_users')
    cond << " AND report_on BETWEEN '#{@scrum_date_from}' AND '#{@scrum_date_to}'"
    @scrum_count = Scrum.count(:conditions => cond)
    @scrum_pages, @scrums = paginate(:scrum, :conditions => cond, :order => "#{Scrum.table_name}.report_on DESC, #{Scrum.table_name}.updated_at DESC", :per_page => 10)
    render :partial => 'show_list', :locals => {:scrums => @scrums, :scrum_pages => @scrum_pages, :count => @scrum_count}
  end
 
  def pager 
    @user = User.current
    @projects_by_manager = @user.manager_role_for_project(@user.projects)
    cond = "project_id = #{@projects_by_manager[0].id} AND report_on = '#{Date.today}'"
    @scrum_pages, @scrums = paginate(:scrum, :conditions => cond, :order => "#{Scrum.table_name}.report_on DESC, #{Scrum.table_name}.updated_at DESC", :per_page => 10)
    @scrum_count = Scrum.count(:conditions => cond)
    render :partial => 'show_list', :locals => {:scrums => @scrums, :scrum_pages => @scrum_pages, :count => @scrum_count}
  end
  
  def popup
    scrum_id = params[:id]
    @scrum = Scrum.find(scrum_id)
    render :partial => 'popup', :locals => {:scrum => @scrum}
  end
 
  private
  def find_project
    @project=Project.find(params[:id])
  end
  
  def is_member?
    if ['Developer', 'Manager', 'Reporter'].include?(User.current.role_for_project(@project).name)
      true
    else  
      deny_access
    end
  end
end#Class ScrumsController