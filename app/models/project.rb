module ScrumProject
  def self.included(base)
    base.send(:has_many,:scrums)       
  end  
end

Project.send(:include,ScrumProject)