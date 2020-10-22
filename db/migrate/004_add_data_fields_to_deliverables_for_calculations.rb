class AddDataFieldsToDeliverablesForCalculations < ActiveRecord::Migration
  def change
    add_column :deliverables, :overhead, :decimal, precision: 15, :scale => 2
    add_column :deliverables, :materials, :decimal, precision: 15, :scale => 2
    add_column :deliverables, :profit, :decimal, precision: 15, :scale => 2
    add_column :deliverables, :cost_per_hour, :decimal, precision: 15, :scale => 2
    add_column :deliverables, :total_hours, :decimal, precision: 15, :scale => 2
    add_column :deliverables, :fixed_cost, :decimal, precision: 15, scale: 2
  end
end
