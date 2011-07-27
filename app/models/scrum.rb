class Scrum < ActiveRecord::Base
  belongs_to :user
  belongs_to :project
  
  validates_presence_of :task_done, :todo

  def self.get_scrum_for(project, date, user = User.current.id)
    find(:first, :conditions => {:project_id => project, :user_id => user, :report_on => date})
  end
  
  # Users that have scrums
  def assignable_users
    project.assignable_users
  end
  
end

