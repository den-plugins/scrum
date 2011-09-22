require_dependency 'my_controller'

class MyController
  unloadable
  
  helper :scrums  
  before_filter :filters, :only => [ :page, :add_block ]

  def page

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

    retrieve_date_range(params[:period_type],params[:period])
    @columns = (params[:columns] && %w(year month week day).include?(params[:columns])) ? params[:columns] : 'month'
    @query = (params[:query].blank?)? "user" : params[:query]
    @disable_acctype_options = (@query == "user")? true : false
    @eng_only, eng_only = (params[:eng_only] == "1" || params[:right].blank? )? [true, "is_engineering = true"] : [false, nil] 
    @for_acctg = (params[:for_acctg] == "1" )? true : false
    @show_only = (params[:show_only].blank?)? "both" : params[:show_only]
    @tall ||= []

    @selected_acctype = ((params[:acctype].blank?)? "" : params[:acctype]).to_i
    @acctype_options = [["All", ""]]
    Enumeration.accounting_types.each do |at|
      @acctype_options << [at.name, at.id]
    end
    
    user_select = "id, firstname, lastname, status"
    user_order = "firstname asc, lastname asc"
    project_select = "id, name"
    project_order = "name asc"
    
    
    if @query == "user"
      available_user_conditions = []
      available_user_conditions << "\"users\".\"status\" = 1"
      available_user_conditions << eng_only
      available_user_conditions << ( (params[:selectednames].blank?)? nil : "id not in (#{params[:selectednames].join(',')})")
      available_user_conditions = available_user_conditions.compact.join(" and ")
      @available_users = User.all(:select => user_select,
                                  :conditions => available_user_conditions,
                                  :order => user_order)
      
      selected_user_conditions = []
      selected_user_conditions << "\"users\".\"status\" = 1"
      selected_user_conditions << eng_only
      selected_user_conditions << ( (params[:selectednames].blank?)? "id is null" : "id in (#{params[:selectednames].join(',')})")
      selected_user_conditions = selected_user_conditions.compact.join(" and ")
      @selected_users = User.all(:select => user_select,
                                  :conditions => selected_user_conditions,
                                  :include => [:memberships],
                                  :order => user_order)
      @available_projects = Project.active.all(:select => project_select,
                                        :order => project_order )
      @selected_projects = []
    else
      available_project_conditions = []
      available_project_conditions << ( (@selected_acctype == 0)? nil : "\"projects\".\"acctg_type\" = #{params[:acctype]}")
      available_project_conditions << ( (params[:selectedprojects].blank?)? nil : "id not in (#{params[:selectedprojects].join(',')})")
      available_project_conditions = available_project_conditions.compact.join(" and ")
      #available_project_conditions = ( (params[:selectedprojects].blank?)? "" : "id not in (#{params[:selectedprojects].join(',')})")
      @available_projects = Project.active.all(:select => project_select,
                                        :conditions => available_project_conditions,
                                        :order => project_order)
      selected_project_conditions = ( (params[:selectedprojects].blank?)? "id is null" : "id in (#{params[:selectedprojects].join(',')})")
      @selected_projects = Project.active.all(:select => project_select,
                                       :conditions => selected_project_conditions,
                                       :order => project_order)
      selected_user_conditions = []
      selected_user_conditions << "\"users\".\"status\" = 1"
      selected_user_conditions << eng_only
      selected_user_conditions << ( (@selected_projects.size > 0)? "users.id in ( select m.user_id from members as m where m.project_id in( #{@selected_projects.collect(&:id).join(',')} ) )" : "id is null")
      selected_user_conditions = selected_user_conditions.compact.join(" and ")
      @selected_users = User.all( :select => user_select,
                                   :conditions => selected_user_conditions,
                                   :include => [:projects, {:memberships, :role }],
                                   :order => user_order)
                                   
      available_user_conditions = []
      available_user_conditions << "\"users\".\"status\" = 1"
      available_user_conditions << eng_only
      available_user_conditions << ((@selected_users.size > 0)? "id not in (#{@selected_users.collect(&:id).join(',')})" : nil )
      available_user_conditions = available_user_conditions.compact.join(" and ")
      @available_users = User.all(:select => user_select,
                                  :conditions => available_user_conditions,
                                  :order => user_order)
    end
    
    if params[:eng_only_csv]
      @selected_users = User.all( :select => "id, firstname, lastname", 
                        :conditions => "is_engineering = true and status = 1",
                        :order      => "firstname asc, lastname asc")
    end
    
    user_list = (@selected_users.size > 0)? "time_entries.user_id in (#{@selected_users.collect(&:id).join(',')}) and" : ""
    project_list = (@selected_projects.size > 0)? "time_entries.project_id in (#{@selected_projects.collect(&:id).join(',')}) and" : ""   
    bounded_time_entries_billable = TimeEntry.find(:all, 
                                :conditions => ["#{user_list} #{project_list} spent_on between ? and ? and issues.acctg_type = (select id from enumerations where name = 'Billable')",
                                @from, @to],
                                :include => [:project],
                                :joins => [:issue],
                                :order => "projects.name asc" )
    bounded_time_entries_billable.each{|v| v.billable = true }
    bounded_time_entries_non_billable = TimeEntry.find(:all, 
                                :conditions => ["#{user_list} #{project_list} spent_on between ? and ? and issues.acctg_type = (select id from enumerations where name = 'Non-billable')",
                                @from, @to],
                                :include => [:project],
                                :joins => [:issue],
                                :order => "projects.name asc" )
    bounded_time_entries_non_billable.each{|v| v.billable = false }
    time_entries = TimeEntry.find(:all, 
                                :conditions => ["#{user_list} spent_on between ? and ?", 
                                @from, @to] )                            
                               
    ######################################
    # th = total hours regardless of selected projects
    # tth = total hours on selected projects
    # tbh = total billable hours on selected projects
    # tnbh = total non-billable hours on selected projects
    ######################################
    @th = time_entries.collect(&:hours).compact.sum
    @tbh = bounded_time_entries_billable.collect(&:hours).compact.sum
    @tnbh = bounded_time_entries_non_billable.collect(&:hours).compact.sum
    @thos = (@tbh + @tnbh)
    @summary = []
    
    if @for_acctg
      @total_internal_rates = []
      @total_computed_internal_rates = []
      @total_sow_rates = []
      @total_computed_sow_rates = []
    end
    @selected_users.each do |usr|
      if usr.class.to_s == "User"
        b = bounded_time_entries_billable.select{|v| v.user_id == usr.id }
        nb = bounded_time_entries_non_billable.select{|v| v.user_id == usr.id }
        x = Hash.new
        
        if @for_acctg
          internal_rate = []
          computed_internal_rate = []
          sow_rate = []
          computed_sow_rate = []
        end
        if @for_acctg
          usr.memberships.each do |r|
              hours = b.select{|v| v.project_id == r.project_id}.collect(&:hours).compact.sum
              inthours = hours*r.internal_rate.to_f
              sowhours = hours*r.sow_rate.to_f
              if inthours > 0  
                internal_rate << sprintf("%.2f", r.internal_rate)
                computed_internal_rate << sprintf("%.2f", inthours)
              end
              if sowhours > 0
                sow_rate << sprintf("%.2f", r.sow_rate)
                computed_sow_rate << sprintf("%.2f", sowhours)
              end
          end
          @total_internal_rates << internal_rate.inject(0) { |s,v| s += v.to_f }
          @total_computed_internal_rates << computed_internal_rate.inject(0) { |s,v| s += v.to_f }
          @total_sow_rates << sow_rate.inject(0) { |s,v| s += v.to_f }
          @total_computed_sow_rates << computed_sow_rate.inject(0) { |s,v| s += v.to_f }
        end
        
        jt = []
        if @query == "user"
          @selected_projects.each do |project|
            usr.memberships.each do |membership|
              if membership.project_id == project.id 
                jt << membership.role.name
              end
            end
          end
        else
          @selected_projects.each do |project|
            usr.memberships.each do |membership|
              if membership.project_id == project.id 
                jt << membership.role.name
              end
            end
          end
        end
        jt = jt.uniq.compact.join(' / ')
        
        x[:user_id] = usr.id
        x[:name] = usr.name
        x[:job_title] = jt 
        x[:entries] = b + nb
        x[:total_hours] = time_entries.select{|v| v.user_id == usr.id }.collect(&:hours).compact.sum
        x[:billable_hours] = b.collect(&:hours).compact.sum
        x[:non_billable_hours] = nb.collect(&:hours).compact.sum
        x[:total_hours_on_selected] = x[:billable_hours] + x[:non_billable_hours]
        if @for_acctg
          x[:internal_rate] = internal_rate.join(" / ")
          x[:computed_internal_rate] = computed_internal_rate.join(" / ")
          x[:sow_rate] = sow_rate.join(" / ")
          x[:computed_sow_rate] = computed_sow_rate.join(" / ")
        end
        @summary.push(x)
      end
    end
    
    if @for_acctg
      @total_internal_rates = @total_internal_rates.inject(0) { |s,v| s += v }
      @total_computed_internal_rates = @total_computed_internal_rates.inject(0) { |s,v| s += v }
      @total_sow_rates = @total_sow_rates.inject(0) { |s,v| s += v }
      @total_computed_sow_rates = @total_computed_sow_rates.inject(0) { |s,v| s += v }
      
      @total_internal_rates = 0 if @total_internal_rates.blank?
      @total_computed_internal_rates = 0 if @total_computed_internal_rates.blank?
      @total_sow_rates = 0 if @total_sow_rates.blank?
      @total_computed_sow_rates = 0 if @total_computed_sow_rates.blank?
    end
    
    @summary = @summary.sort_by{|c| "#{c[:job_title]}#{c[:name]}" }
    
  end 
  
  def retrieve_default_date
    @scrum_date_from = Date.civil(Date.today.year, Date.today.month, 1)
    @scrum_date_to = (@scrum_date_from >> 1) - 1
  end
  
  # Retrieves the date range based on predefined ranges or specific from/to param dates
  def retrieve_date_range(period_type,period)
    @free_period = false
    @from, @to = nil, nil

    if period_type == '1' || (period_type.nil? && !period_type.nil?)
      case period.to_s
      when 'today'
        @from = @to = Date.today
      when 'yesterday'
        @from = @to = Date.today - 1
      when 'current_week'
        @from = Date.today - (Date.today.cwday - 1)%7
        @to = @from + 6
      when 'last_week'
        @from = Date.today - 7 - (Date.today.cwday - 1)%7
        @to = @from + 6
      when '7_days'
        @from = Date.today - 7
        @to = Date.today
      when 'current_month'
         current_month
      when 'last_month'
        @from = Date.civil(Date.today.year, Date.today.month, 1) << 1
        @to = (@from >> 1) - 1
      when '30_days'
        @from = Date.today - 30
        @to = Date.today
      when 'current_year'
        @from = Date.civil(Date.today.year, 1, 1)
        @to = Date.civil(Date.today.year, 12, 31)
      end
    elsif period_type == '2' || (period_type.nil? && (!params[:from].nil? || !params[:to].nil?))
      begin; @from = params[:from].to_s.to_date unless params[:from].blank?; rescue; end
      begin; @to = params[:to].to_s.to_date unless params[:to].blank?; rescue; end
      begin; @from = params[:leaves_from].to_s.to_date unless params[:leaves_from].blank?; rescue; end
      begin; @to = params[:leaves_to].to_s.to_date unless params[:leaves_to].blank?; rescue; end
      @free_period = true
    else
      # default
      current_month
    end
    
    @from, @to = @to, @from if @from && @to && @from > @to
    @from ||= (TimeEntry.minimum(:spent_on, :include => :project, :conditions => Project.allowed_to_condition(User.current, :view_time_entries)) || Date.today) - 1
    @to   ||= (TimeEntry.maximum(:spent_on, :include => :project, :conditions => Project.allowed_to_condition(User.current, :view_time_entries)) || Date.today)
  end

  def current_month
    @from = Date.civil(Date.today.year, Date.today.month, 1)
    @to = (@from >> 1) - 1
  end


private

	def filters
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

    retrieve_date_range(params[:period_type],params[:period])
    @columns = (params[:columns] && %w(year month week day).include?(params[:columns])) ? params[:columns] : 'month'
    @query = (params[:query].blank?)? "user" : params[:query]
    @disable_acctype_options = (@query == "user")? true : false
    @eng_only, eng_only = (params[:eng_only] == "1" || params[:right].blank? )? [true, "is_engineering = true"] : [false, nil] 
    @for_acctg = (params[:for_acctg] == "1" )? true : false
    @show_only = (params[:show_only].blank?)? "both" : params[:show_only]
    @tall ||= []

    @selected_acctype = ((params[:acctype].blank?)? "" : params[:acctype]).to_i
    @acctype_options = [["All", ""]]
    Enumeration.accounting_types.each do |at|
      @acctype_options << [at.name, at.id]
    end

    user_select = "id, firstname, lastname, status"
    user_order = "firstname asc, lastname asc"
    project_select = "id, name"
    project_order = "name asc"
    
    
    if @query == "user"
      available_user_conditions = []
      available_user_conditions << "\"users\".\"status\" = 1"
      available_user_conditions << eng_only
      available_user_conditions << ( (params[:selectednames].blank?)? nil : "id not in (#{params[:selectednames].join(',')})")
      available_user_conditions = available_user_conditions.compact.join(" and ")
      @available_users = User.all(:select => user_select,
                                  :conditions => available_user_conditions,
                                  :order => user_order)
      
      selected_user_conditions = []
      selected_user_conditions << "\"users\".\"status\" = 1"
      selected_user_conditions << eng_only
      selected_user_conditions << ( (params[:selectednames].blank?)? "id is null" : "id in (#{params[:selectednames].join(',')})")
      selected_user_conditions = selected_user_conditions.compact.join(" and ")
      @selected_users = User.all(:select => user_select,
                                  :conditions => selected_user_conditions,
                                  :include => [:memberships],
                                  :order => user_order)
      @available_projects = Project.active.all(:select => project_select,
                                        :order => project_order )
      @selected_projects = []
    else
      available_project_conditions = []
      available_project_conditions << ( (@selected_acctype == 0)? nil : "\"projects\".\"acctg_type\" = #{params[:acctype]}")
      available_project_conditions << ( (params[:selectedprojects].blank?)? nil : "id not in (#{params[:selectedprojects].join(',')})")
      available_project_conditions = available_project_conditions.compact.join(" and ")
      #available_project_conditions = ( (params[:selectedprojects].blank?)? "" : "id not in (#{params[:selectedprojects].join(',')})")
      @available_projects = Project.active.all(:select => project_select,
                                        :conditions => available_project_conditions,
                                        :order => project_order)
      selected_project_conditions = ( (params[:selectedprojects].blank?)? "id is null" : "id in (#{params[:selectedprojects].join(',')})")
      @selected_projects = Project.active.all(:select => project_select,
                                       :conditions => selected_project_conditions,
                                       :order => project_order)
      selected_user_conditions = []
      selected_user_conditions << "\"users\".\"status\" = 1"
      selected_user_conditions << eng_only
      selected_user_conditions << ( (@selected_projects.size > 0)? "users.id in ( select m.user_id from members as m where m.project_id in( #{@selected_projects.collect(&:id).join(',')} ) )" : "id is null")
      selected_user_conditions = selected_user_conditions.compact.join(" and ")
      @selected_users = User.all( :select => user_select,
                                   :conditions => selected_user_conditions,
                                   :include => [:projects, {:memberships, :role }],
                                   :order => user_order)
                                   
      available_user_conditions = []
      available_user_conditions << "\"users\".\"status\" = 1"
      available_user_conditions << eng_only
      available_user_conditions << ((@selected_users.size > 0)? "id not in (#{@selected_users.collect(&:id).join(',')})" : nil )
      available_user_conditions = available_user_conditions.compact.join(" and ")
      @available_users = User.all(:select => user_select,
                                  :conditions => available_user_conditions,
                                  :order => user_order)
    end
    
    if params[:eng_only_csv]
      @selected_users = User.all( :select => "id, firstname, lastname", 
                        :conditions => "is_engineering = true and status = 1",
                        :order      => "firstname asc, lastname asc")
    end
    
    user_list = (@selected_users.size > 0)? "time_entries.user_id in (#{@selected_users.collect(&:id).join(',')}) and" : ""
    project_list = (@selected_projects.size > 0)? "time_entries.project_id in (#{@selected_projects.collect(&:id).join(',')}) and" : ""   
    bounded_time_entries_billable = TimeEntry.find(:all, 
                                :conditions => ["#{user_list} #{project_list} spent_on between ? and ? and issues.acctg_type = (select id from enumerations where name = 'Billable')",
                                @from, @to],
                                :include => [:project],
                                :joins => [:issue],
                                :order => "projects.name asc" )
    bounded_time_entries_billable.each{|v| v.billable = true }
    bounded_time_entries_non_billable = TimeEntry.find(:all, 
                                :conditions => ["#{user_list} #{project_list} spent_on between ? and ? and issues.acctg_type = (select id from enumerations where name = 'Non-billable')",
                                @from, @to],
                                :include => [:project],
                                :joins => [:issue],
                                :order => "projects.name asc" )
    bounded_time_entries_non_billable.each{|v| v.billable = false }
    time_entries = TimeEntry.find(:all, 
                                :conditions => ["#{user_list} spent_on between ? and ?", 
                                @from, @to] )                            
                               
    ######################################
    # th = total hours regardless of selected projects
    # tth = total hours on selected projects
    # tbh = total billable hours on selected projects
    # tnbh = total non-billable hours on selected projects
    ######################################
    @th = time_entries.collect(&:hours).compact.sum
    @tbh = bounded_time_entries_billable.collect(&:hours).compact.sum
    @tnbh = bounded_time_entries_non_billable.collect(&:hours).compact.sum
    @thos = (@tbh + @tnbh)
    @summary = []
    
    if @for_acctg
      @total_internal_rates = []
      @total_computed_internal_rates = []
      @total_sow_rates = []
      @total_computed_sow_rates = []
    end
    @selected_users.each do |usr|
      if usr.class.to_s == "User"
        b = bounded_time_entries_billable.select{|v| v.user_id == usr.id }
        nb = bounded_time_entries_non_billable.select{|v| v.user_id == usr.id }
        x = Hash.new
        
        if @for_acctg
          internal_rate = []
          computed_internal_rate = []
          sow_rate = []
          computed_sow_rate = []
        end
        if @for_acctg
          usr.memberships.each do |r|
              hours = b.select{|v| v.project_id == r.project_id}.collect(&:hours).compact.sum
              inthours = hours*r.internal_rate.to_f
              sowhours = hours*r.sow_rate.to_f
              if inthours > 0  
                internal_rate << sprintf("%.2f", r.internal_rate)
                computed_internal_rate << sprintf("%.2f", inthours)
              end
              if sowhours > 0
                sow_rate << sprintf("%.2f", r.sow_rate)
                computed_sow_rate << sprintf("%.2f", sowhours)
              end
          end
          @total_internal_rates << internal_rate.inject(0) { |s,v| s += v.to_f }
          @total_computed_internal_rates << computed_internal_rate.inject(0) { |s,v| s += v.to_f }
          @total_sow_rates << sow_rate.inject(0) { |s,v| s += v.to_f }
          @total_computed_sow_rates << computed_sow_rate.inject(0) { |s,v| s += v.to_f }
        end
        
        jt = []
        if @query == "user"
          @selected_projects.each do |project|
            usr.memberships.each do |membership|
              if membership.project_id == project.id 
                jt << membership.role.name
              end
            end
          end
        else
          @selected_projects.each do |project|
            usr.memberships.each do |membership|
              if membership.project_id == project.id 
                jt << membership.role.name
              end
            end
          end
        end
        jt = jt.uniq.compact.join(' / ')
        
        x[:user_id] = usr.id
        x[:name] = usr.name
        x[:job_title] = jt 
        x[:entries] = b + nb
        x[:total_hours] = time_entries.select{|v| v.user_id == usr.id }.collect(&:hours).compact.sum
        x[:billable_hours] = b.collect(&:hours).compact.sum
        x[:non_billable_hours] = nb.collect(&:hours).compact.sum
        x[:total_hours_on_selected] = x[:billable_hours] + x[:non_billable_hours]
        if @for_acctg
          x[:internal_rate] = internal_rate.join(" / ")
          x[:computed_internal_rate] = computed_internal_rate.join(" / ")
          x[:sow_rate] = sow_rate.join(" / ")
          x[:computed_sow_rate] = computed_sow_rate.join(" / ")
        end
        @summary.push(x)
      end
    end
    
    if @for_acctg
      @total_internal_rates = @total_internal_rates.inject(0) { |s,v| s += v }
      @total_computed_internal_rates = @total_computed_internal_rates.inject(0) { |s,v| s += v }
      @total_sow_rates = @total_sow_rates.inject(0) { |s,v| s += v }
      @total_computed_sow_rates = @total_computed_sow_rates.inject(0) { |s,v| s += v }
      
      @total_internal_rates = 0 if @total_internal_rates.blank?
      @total_computed_internal_rates = 0 if @total_computed_internal_rates.blank?
      @total_sow_rates = 0 if @total_sow_rates.blank?
      @total_computed_sow_rates = 0 if @total_computed_sow_rates.blank?
    end
    
    @summary = @summary.sort_by{|c| "#{c[:job_title]}#{c[:name]}" }
	end
end#Class MyController
