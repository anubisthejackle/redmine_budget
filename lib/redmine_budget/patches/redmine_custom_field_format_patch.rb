module RedmineBudget::Patches::RedmineCustomFieldFormatPatch
  def self.included(base)
    base.send(:include, InstanceMethods)
  end

  module InstanceMethods
    def format_as_deliverable(value)
      value.blank? ? '' : Deliverable.find_by_id(value).to_s
    end
  end
end
