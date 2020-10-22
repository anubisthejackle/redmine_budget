class DeliverableWorkflowRule < ActiveRecord::Base
  self.table_name = "#{table_name_prefix}deliverable_workflows#{table_name_suffix}"

  belongs_to :role
  belongs_to :old_status, class_name: 'DeliverableStatus'
  belongs_to :new_status, class_name: 'DeliverableStatus'
end
