module RedmineBudget::Patches::CustomFieldPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      alias_method_chain :possible_values_options, :deliverable
      alias_method_chain :possible_values, :deliverable
      alias_method_chain :cast_value, :deliverable
      alias_method_chain :value_class, :deliverable
      alias_method_chain :set_searchable, :deliverable
    end

    update_field_format_validation
    inject_custom_fields
  end

  def self.inject_custom_fields
    name = 'DeliverableCustomField'

    CustomField::CUSTOM_FIELDS_TABS << { name: name,
                                         partial: 'custom_fields/index',
                                         label: :label_deliverable_plural }
    CustomField::CUSTOM_FIELDS_NAMES << name
  end

  def self.update_field_format_validation
    old_values = Redmine::CustomFieldFormat.available_formats

    Redmine::CustomFieldFormat.register 'deliverable',
                                        only: %w(Issue), edit_as: 'list'

    # look for proper validator
    CustomField.validators_on(:field_format).each do |val|
      next if ((val.options[:in] || []) & old_values).empty?

      values = Redmine::CustomFieldFormat.available_formats

      val.instance_variable_set(:@options, { in: values })
      val.instance_variable_set(:@delimiter, values)

      break
    end
  end

  module InstanceMethods
    def set_searchable_with_deliverable
      if self.multiple
        set_searchable_without_deliverable
        self.multiple = true
      else
        set_searchable_without_deliverable
      end
    end

    def possible_values_options_with_deliverable(obj = nil)
      if field_format == 'deliverable'
        if obj.respond_to?(:project) && obj.project
          values = Deliverable.active.order(:subject).settable(obj.project)
                     .map { |d| [d.to_s, d.id.to_s] }
        elsif obj.is_a?(Array)
          values = obj.map { |o| possible_values_options(o) }.reduce(:&)
        else
          values = Deliverable.visible.active.order(:subject)
                     .map { |d| [d.to_s, d.id.to_s] }
        end

        # Add existing deliverable if it's not already there to prevent deletion
        # when updating issue.
        if obj.is_a?(Issue)
          existing_cv = obj.custom_value_for(self)

          if existing_cv
            existing = Deliverable.find_by_id(existing_cv.value)

            if existing
              existing_value = [existing.to_s, existing.id.to_s]
              values << existing_value unless values.include?(existing_value)
            end
          end
        end

        values
      else
        possible_values_options_without_deliverable(obj)
      end
    end

    def possible_values_with_deliverable(obj = nil)
      if field_format == 'deliverable'
        possible_values_options(obj).collect(&:last)
      else
        possible_values_without_deliverable(obj)
      end
    end

    def cast_value_with_deliverable(value)
      if value and field_format == 'deliverable'
        Deliverable.find_by_id(value)
      else
        cast_value_without_deliverable(value)
      end
    end

    def value_class_with_deliverable
      if field_format == 'deliverable'
        Deliverable
      else
        value_class_without_deliverable
      end
    end
  end
end
