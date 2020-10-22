class MoveIssueDeliverableToCustomFields < ActiveRecord::Migration
  def up
    issues = Issue.select([:id, :deliverable_id]).where('deliverable_id IS NOT NULL')


    # Create Custom Field to store relations
    cf_name = I18n.t(:label_deliverable)
    existing = IssueCustomField.where(name: cf_name)
    cf_name = "#{cf_name} (redmine_budget)" if existing.any?

    custom_field = IssueCustomField.create!(name: cf_name,
                                           field_format: 'deliverable',
                                           is_for_all: true,
                                           trackers: Tracker.all)
    if issues.empty?
      remove_column :issues, :deliverable_id

      return
    end


    details = JournalDetail.where(property: 'attr', prop_key: 'deliverable_id')

    # Update attributes for journals
    ActiveRecord::Base.transaction do
      details.each do |detail|
        if detail.property == 'attr' && detail.prop_key == 'deliverable_id'
          detail.update_attributes property: 'cf',
                                   prop_key: custom_field.id
        end
      end
    end

    # Fill values for Custom Fields to create relations
    ActiveRecord::Base.transaction do
      issues.each do |issue|
        CustomValue.create(customized_type: 'Issue',
                           customized_id: issue.id,
                           custom_field_id: custom_field.id,
                           value: issue.deliverable_id)
      end
    end

    # Remove old reference column
    remove_column :issues, :deliverable_id
  end

  def down
    add_column :issues, :deliverable_id, :integer

    # Find Issue CustomValues containing references to Deliverables
    ids = CustomValue.select([:customized_id, :value]).joins(:custom_field)
          .where(custom_fields: { field_format: 'deliverable' })
          .index_by(&:customized_id)
    issue_by_id = Issue.where(id: ids.keys).index_by(&:id)

    # Save foreign keys to column
    ActiveRecord::Base.transaction do
      ids.each do |issue_id, value|
        issue = issue_by_id[issue_id.to_i]

        issue.update_attribute :deliverable_id, value
      end
    end

    cf_ids = CustomField.where(field_format: 'deliverable').pluck(:id).map(&:to_s)
    details = JournalDetail.where(property: 'cf', prop_key: cf_ids)

    # Update attributes for journals
    ActiveRecord::Base.transaction do
      details.each do |detail|
        if detail.property == 'cf' && cf_ids.include?(detail.prop_key)
          detail.update_attributes property: 'attr',
                                   prop_key: 'deliverable_id'
        end
      end
    end

    # Delete all Custom Fields related to Deliverables
    IssueCustomField.where(field_format: 'deliverable').destroy_all
  end
end
