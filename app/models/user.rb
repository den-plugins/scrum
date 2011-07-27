module ScrumUser
  def self.included(base)
    base.send(:has_many,:scrums)
  end
  
  def submitted_scrum_for?(project,date)
    scrums.find(:first,:conditions=>{:project_id=>project.id,:report_on=>date.to_s}) ? true : false
  end

  def submitted_scrum(project, date)
    scrums.find(:first, :conditions => {:project_id => project.id, :report_on => date.to_s})
  end

  def manager_role_for_project(projects)
    user_projects = []
    projects.each do |project|
      user_projects << project if self.role_for_project(project).name.eql?('Manager')
    end
    return user_projects
  end
  
end

module Dummy
  class User < User
    has_many :resources, :foreign_key => "user_id"
  end
  
  def resources
    if self.login.eql?('dummyuser')
      Dummy::User.find(:last).resources
    end
  end
end

User.send(:include,ScrumUser)
User.send(:include,Dummy)