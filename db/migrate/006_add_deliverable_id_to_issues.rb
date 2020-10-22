class AddDeliverableIdToIssues < ActiveRecord::Migration
  def change
    add_column :issues, :deliverable_id, :integer
  end
end
