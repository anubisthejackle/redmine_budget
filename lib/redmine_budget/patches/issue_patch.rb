module RedmineBudget::Patches::IssuePatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      alias_method_chain :read_only_attribute_names, :deliverable
    end
  end

  module InstanceMethods
    # Wraps the association to get the Deliverable subject.  Needed for the
    # Query and filtering
    def deliverable_subject
      deliverable.try :subject
    end

    def deliverable
      cf_id = RedmineBudget.cf_id
      deliverable_id = custom_field_value(cf_id)

      if cf_id and deliverable_id
        Deliverable.find_by_id
      end
    end

    def deliverable=(deliverable)
      return if RedmineBudget.cf_id.nil?

      self.custom_field_values = {
        RedmineBudget.cf_id.to_s => deliverable.id
      }
    end

    def read_only_attribute_names_with_deliverable(*args)
      unless @__budget_readonly_cfs
        if User.current.allowed_to?(:set_deliverable, project)
          @__budget_readonly_cfs = []
        else
          @__budget_readonly_cfs = RedmineBudget.cf_ids.map(&:to_s)
        end
      end

      read_only_attribute_names_without_deliverable(*args).concat(@__budget_readonly_cfs)
    end
  end
end
