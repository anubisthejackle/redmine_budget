class AddRateToMembers < ActiveRecord::Migration
  def change
    add_column :members, :rate, :decimal, precision: 15, scale: 2
  end
end
