class CreateDeliverableStatuses < ActiveRecord::Migration
  def change
    create_table :deliverable_statuses do |t|
      t.column :name, :string, null: false
      t.column :position, :integer, default: 1
      t.column :is_default, :boolean, null: false, default: false
      t.column :is_closed, :boolean, null: false, default: false
      t.column :is_protected, :boolean, null: false, default: false
    end

    add_column :deliverables, :status_id, :integer
  end
end
