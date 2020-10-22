module RedmineBudget::Patches::QueryPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      alias_method_chain :add_custom_fields_filters, :deliverable
    end
  end

  module InstanceMethods
    def add_custom_fields_filters_with_deliverable(custom_fields, assoc=nil)
      add_custom_fields_filters_without_deliverable(custom_fields, assoc)

      @available_filters.each do |k, v|
        next if v[:format] != 'deliverable'

        v[:type] = :list_optional
        v[:values] = v[:field].possible_values_options(project)
      end
    end
  end
end
