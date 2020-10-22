module RedmineBudget
  PLUGIN_ID = name.underscore.to_sym

  PATCHES = [
    'Issue',
    'Query'
  ]

  DEPENDENCIES = [
    'redmine_budget/hook',
    'deliverable_custom_field'
  ]

  module Settings
    class << self
      def defaults
        Redmine::Plugin.find(PLUGIN_ID).settings[:default] || {}
      end

      def method_missing(method_name)
        s = Setting.method("plugin_#{PLUGIN_ID}")

        name = method_name.to_s.sub('?', '')

        if defaults.include?(name)
          m = {}
          value = defaults[name]

          case value
          when Array
            m[name] = proc { s.call[name] || value }
            m["#{name}?"] = proc { (s.call[name] || value).any? }
          when Integer
            m[name] = proc { v = s.call[name]; v.present? ? v.to_i : value }
          when TrueClass, FalseClass
            p = proc { v = s.call[name]; v ? (!!v == v ? v : v.to_i > 0) : value }
            m[name] = p
            m["#{name}?"] = p
          else
            m[name] = proc { s.call[name] || value }
            m["#{name}?"] = proc { (s.call[name] || value).present? }
          end

          m.each { |k, v| define_singleton_method(k, v) }

          send(method_name)
        else
          super
        end
      end
    end

    def self.supervisor_group
      Group.find(supervisor_group_id) if supervisor_group_id?
    end
  end

  def self.patch(patches)
    patches.each do |name|
      flat_name = name.gsub('::', '')

      require "#{self.name.underscore}/patches/#{flat_name.underscore}_patch"

      base = name.constantize
      patch = "#{self.name}::Patches::#{flat_name}Patch".constantize

      next if base.included_modules.include?(patch)

      if patch.const_defined?(:ClassMethods)
        base.send(:extend, patch.const_get(:ClassMethods))
      end

      if patch.const_defined?(:InstanceMethods)
        base.send(:include, patch.const_get(:InstanceMethods))
      end

      base.send(:include, patch)
    end
  end

  def self.require_dependencies
    DEPENDENCIES.each { |name| require_dependency(name) }
  end

  def self.add_custom_fields
    if Redmine::VERSION::MAJOR >= 3
      patches = ['CustomFieldsHelper']

      require "#{self.name.underscore}/field_format"
    else
      patches = ['CustomField', 'Redmine::CustomFieldFormat']
    end

    patch(patches)
  end

  def self.install
    require_dependencies
    add_custom_fields
    patch(PATCHES)
  end

  def self.cf_ids
    Rails.cache.fetch('redminn_budget_cf_ids', expires_in: 2.minutes) do
      CustomField.where(field_format: 'deliverable').pluck(:id)
    end
  end

  def self.cf_id
    cf_ids.first
  end

  def self.custom_field
    CustomField.sorted.where(field_format: 'deliverable').first
  end

  # Budget requires the Rate plugin
  def self.require_rate_plugin
    begin
      require_dependency 'rate'
    rescue LoadError
      # rate_plugin is not installed
      raise Exception.new("ERROR: The Rate plugin is not installed.  Please install the Rate plugin from https://projects.littlestreamsoftware.com/projects/redmine-rate")
    end unless Object.const_defined?('Rate')
  end
end
