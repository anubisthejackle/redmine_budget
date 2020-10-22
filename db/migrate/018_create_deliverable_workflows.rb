class CreateDeliverableWorkflows < ActiveRecord::Migration
  def change
    create_table :deliverable_workflows do |t|
      t.column :old_status_id, :integer
      t.column :new_status_id, :integer
      t.column :role_id, :integer
    end
  end
end
