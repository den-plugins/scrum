class CreateScrums < ActiveRecord::Migration
  
  def self.up
    create_table :scrums, :force => true do |t|
        t.column :user_id, :integer, :null => false
        t.column :project_id, :integer, :null => false
        t.column :task_done, :string, :limit => 255, :default => "", :null => false
        t.column :todo, :string, :limit => 255, :default => "", :null => false
        t.column :roadblocks, :string, :limit => 255, :default => "", :null => false
        t.column :report_on,:date
        t.column :created_at, :datetime, :null => false
        t.column :updated_at, :datetime, :null => false
    end
  end

  def self.down
    drop_table :scrums
  end  
   
end
