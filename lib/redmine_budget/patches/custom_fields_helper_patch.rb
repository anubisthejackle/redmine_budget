module RedmineBudget::Patches::CustomFieldsHelperPatch
  def self.included(base) # :nodoc:
    inject_custom_fields
  end

  def self.inject_custom_fields
    name = 'DeliverableCustomField'

    CustomFieldsHelper::CUSTOM_FIELDS_TABS << { name: name,
                                                partial: 'custom_fields/index',
                                                label: :label_deliverable_plural }
  end
end
