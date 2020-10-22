class AddPercentageFieldsToDeliverables < ActiveRecord::Migration
  def change
    add_column :deliverables, :overhead_percent, :integer
    add_column :deliverables, :materials_percent, :integer
    add_column :deliverables, :profit_percent, :integer
  end
end
