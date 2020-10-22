class PopulateDeliverableWorkflows < ActiveRecord::Migration
  def up
    statuses = DeliverableStatus.all

    Role.all.each do |role|
      statuses.each do |old_status|
        new_statuses = statuses - [old_status]

        new_statuses.each do |new_status|
          DeliverableWorkflowRule.create(role_id: role.id,
                                         old_status_id: old_status.id,
                                         new_status_id: new_status.id)
        end
      end
    end
  end

  def down
    DeliverableWorkflowRule.delete_all
  end
end
