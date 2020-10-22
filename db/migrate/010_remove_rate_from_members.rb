require_dependency 'user'
require_dependency 'member'

class RemoveRateFromMembers < ActiveRecord::Migration
  def self.up
    remove_column :members, :rate
  end

  def self.down
    add_column :members, :rate, :decimal, :precision => 15, :scale => 2
  end
end
