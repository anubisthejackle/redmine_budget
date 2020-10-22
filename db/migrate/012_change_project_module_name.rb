class ChangeProjectModuleName < ActiveRecord::Migration
  def self.up
    EnabledModule.where(name: 'budget_module').update_all(name: 'budget')
  end
  
  def self.down
    EnabledModule.where(name: 'budget').update_all(name: 'budget_module')
  end
end
