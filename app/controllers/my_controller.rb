require_dependency 'my_controller'

class MyController
  unloadable
  
  helper :scrums  
  
  def page
    @user = User.current
    @blocks = @user.pref[:my_page_layout] || DEFAULT_LAYOUT
    #TODO: this line reoccurs, refactor needed
    @sorting_options = {'Priority'=> {:sort_key => 'enumerations.position'},
                        'Category'=> {:sort_key => 'issues.category_id'},
                        'Due Date'=> {:sort_key => 'issues.due_date'},
                        'Date Created'=> {:sort_key => 'issues.created_on'} } 
    @projects_by_manager = @user.manager_role_for_project(@user.projects).sort
    retrieve_default_date
    if !@projects_by_manager.empty?             
      @project_members = @projects_by_manager[0].assignable_users
    else
      if !@user.admin?
        @blocks.each_value do|value|        
          value.delete("time_entries")
          value.delete("leave_entries")
        end
      end
      @blocks.each_value do|value|        
        break if !value.delete("scrums").nil?
      end
    end
    if @user.projects.empty?
      @blocks.each_value do|value|        
        break if !value.delete("timelogging").nil?
      end
    end
  end
  
  def add_block
    block = params[:block]
    render(:nothing => true) and return unless block && (BLOCKS.keys.include? block)
    @user = User.current
    # remove if already present in a group
    %w(top left right).each {|f| (session[:page_layout][f] ||= []).delete block }
    # add it on top
    session[:page_layout]['top'].unshift block
    @projects_by_manager = @user.manager_role_for_project(@user.projects).sort
    if !@projects_by_manager.empty?
      @project_members = @projects_by_manager[0].members.find(:all).sort  
    end
    retrieve_default_date
    render :partial => "block", :locals => {:user => @user, :block_name => block}
  end
  
  def page_layout
    @user = User.current
    @blocks = @user.pref[:my_page_layout] || DEFAULT_LAYOUT.dup       
    @block_options = []
    @projects_by_manager = @user.manager_role_for_project(@user.projects).sort
    retrieve_default_date
    if !@projects_by_manager.empty?
      @project_members = @projects_by_manager[0].members.find(:all).sort 
    else
      if !@user.admin?
        @blocks.each_value do|value|        
          value.delete("time_entries")
          value.delete("leave_entries")
        end
      end
      @blocks.each_value do|value|        
        break if !value.delete("scrums").nil?
      end
    end
    if @user.projects.empty?
      @blocks.each_value do|value|        
        break if !value.delete("timelogging").nil?
      end
    end
    session[:page_layout] = @blocks
    %w(top left right).each {|f| session[:page_layout][f] ||= [] }
    BLOCKS.each do |k, v|
      next if k.eql?('scrums') and @projects_by_manager.empty?
      next if k.eql?('time_entries') and @projects_by_manager.empty? && !@user.admin?
      next if k.eql?('leave_entries') and @projects_by_manager.empty? && !@user.admin?
      next if k.eql?('timelogging') and @user.projects.empty?
        @block_options << [l(v), k]  
    end    
  end 
  
  def retrieve_default_date
    @scrum_date_from = Date.civil(Date.today.year, Date.today.month, 1)
    @scrum_date_to = (@scrum_date_from >> 1) - 1
  end
  
end#Class MyController
