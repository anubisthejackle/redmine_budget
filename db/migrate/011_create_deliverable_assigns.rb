class CreateDeliverableAssigns < ActiveRecord::Migration
  def change
    create_table :deliverable_assigns do |t|
      t.column :deliverable_id, :integer
      t.column :user_id, :integer
      t.column :activity_id, :integer
      t.column :hours, :float
    end

    add_index :deliverable_assigns, [:deliverable_id]
    add_index :deliverable_assigns, [:user_id]
  end
end
