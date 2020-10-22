module RedmineBudget
  module FieldFormat
    include Redmine::FieldFormat

    class DeliverableFormat < RecordList
      add 'deliverable'

      self.multiple_supported = true
      self.searchable_supported = true

      def possible_values_options(custom_field, object=nil)
        possible_values_records(custom_field, object).map {|u| [u.subject, u.id.to_s]}
      end

      def possible_values_records(custom_field, object=nil)
        if object.is_a?(Array)
          projects = object.map { |o| o.respond_to?(:project) ? o.project : nil }.compact.uniq
          projects.map {|project| possible_values_records(custom_field, project)}.reduce(:&) || []
        elsif object.respond_to?(:project) && object.project
          Deliverable.visible.active.where(project: object.project).order(:subject)
        else
          []
        end
      end

      def value_from_keyword(custom_field, keyword, object)
        deliverables = possible_values_records(custom_field, object).to_a
        deliverable = deliverables.detect { |d| keyword.casecmp(d.subject) == 0 }
        deliverable.try(:id)
      end

      def validate_custom_field(custom_field)
        []
      end
    end
  end
end
