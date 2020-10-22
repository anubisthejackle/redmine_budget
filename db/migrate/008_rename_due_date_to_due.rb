class RenameDueDateToDue < ActiveRecord::Migration
  def change
    rename_column :deliverables, :due_date, :due
  end
end
