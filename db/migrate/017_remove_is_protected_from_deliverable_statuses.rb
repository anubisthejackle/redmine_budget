class RemoveIsProtectedFromDeliverableStatuses < ActiveRecord::Migration
  def self.up
    if settings['field_protection'].to_i > 0
      say_with_time "move_protected_fields_settings_to_statuses" do
        move_protected_fields_settings_to_statuses
      end
    end

    remove_column :deliverable_statuses, :is_protected
  end

  def self.down
    add_column :deliverable_statuses, :is_protected, :boolean
  end

  private

  def move_protected_fields_settings_to_statuses
    protected_attributes = settings['protected_attributes'].to_a
    protected_statuses = DeliverableStatus.where(is_protected: true)

    DeliverableStatus.transaction do
      protected_statuses.each do |status|
        status.protected_fields = protected_attributes
        status.save
      end
    end

    new_settings = settings.dup
    new_settings.delete('field_protection')
    new_settings.delete('protected_attributes')

    Setting.plugin_redmine_budget = new_settings
  end

  def settings
    Setting.plugin_redmine_budget
  end
end
