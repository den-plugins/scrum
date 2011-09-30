require 'redmine'

RAILS_DEFAULT_LOGGER.info 'Starting Scrum plugin for RedMine'

Redmine::Plugin.register :scrum do
  name 'Scrum plugin'
  author 'Exist'
  description 'This is a Scrum plugin for Redmine'
  version '0.1.0'
  
  project_module :scrums do
    #permission :index_scrum, {:scrums => [:index]}, :public => true
    #permission :show_scrum, {:scrums => [:show]}, :public => true
    #permission :create_scrum, {:scrums => [:create]}, :public => true
    #permission :update_scrum, {:scrums => [:update]}, :public => true
    #permission :delete_scrum, {:scrums => [:delete]}, :public => true
    #permission :preview, {:scrums => [:preview]}, :public => true
    #permission :project_members_scrum, {:scrums => [:project_members]}, :public => true
    #permission :show_list_scrum, {:scrums => [:show_list]}, :public => true
    permission :enable_scrum, {:scrums => [:index, :show, :create, :update, :delete, :preview, :project_members, :show_list]}
  end
  
  menu :project_menu, :scrums, {:controller => 'scrums', :action => 'index' }, :after => :repository, :caption=>"Scrums"
end

require File.dirname(__FILE__) + '/app/models/user'
require File.dirname(__FILE__) + '/app/models/project'
require File.dirname(__FILE__) + '/app/models/scrum'