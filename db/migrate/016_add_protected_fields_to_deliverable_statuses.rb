class AddProtectedFieldsToDeliverableStatuses < ActiveRecord::Migration
  def change
    add_column :deliverable_statuses, :protected_fields, :text
  end
end
