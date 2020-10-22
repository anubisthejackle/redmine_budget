module DeliverableQueriesHelper
  include ActionView::Helpers::NumberHelper
  include QueriesHelper
  include ApplicationHelper

  def column_content(column, deliverable)
    if column.name == :overview
      deliverable_overview(deliverable)
    else
      super
    end
  end

  def column_value(column, deliverable, value)
    case value
    when String
      if column.name == :subject
        link_to value, deliverable_path(deliverable)
      elsif column.name == :description
        deliverable.description? ? content_tag('div', textilizable(deliverable, :description), class: 'wiki') : ''
      else
        h(value)
      end
    when Time
      format_time(value)
    when Date
      format_date(value)
    when Integer
      if column.name == :id
        link_to(value, deliverable_path(deliverable))
      elsif column.name == :progress
        content_tag('span', progress_bar(value, width: '100%', class: 'done_ratio'), title: "#{value}%")
      elsif column.name == :spent || column.name == :overhead
        currency(value)
      else
        value.to_s
      end
    when Float, BigDecimal
      if column.name.to_s.ends_with?('hours')
        hours(value)
      else
        currency(value)
      end
    when User
      link_to_user value
    when Project
      link_to value, project_deliverables_path(value)
    when TrueClass
      l(:general_text_Yes)
    when FalseClass
      l(:general_text_No)
    else
      h(value)
    end
  end

  def csv_value(column, deliverable, value)
    seperator = l(:general_csv_decimal_separator)

    case value.class
    when Fixnum, BigDecimal
      if column.name == :progress
        "#{value}%"
      elsif ([column.name] & [:spent, :overhead, :budget, :labor_budget, :spent, :materials, :overhead, :protfit]).any?
        "#{number_to_currency(value || 0.0, :format => "%n %u", :unit => "PLN", :separator => seperator, :delimiter => ' ', :precision => 0)}"
      else
        value.to_s
      end
    when Time
      format_time(value)
    when Date
      format_date(value)
    when Float
      if column.name == :total_hours
        sprintf("%.2f", value).gsub('.', seperator)
      else
        "#{number_to_currency(value || 0.0, :format => "%n %u", :unit => "PLN", :separator => seperator, :delimiter => ' ', :precision => 0)}"
      end
    else
      value.to_s
    end
  end

  def suitable_projects
    user = User.current
    project_ids = []

    user.projects.each do |project|
      ok = !!user.roles_for_project(project).find { |r| r.permissions.include?(:view_budget) }
      project_ids << project.id if ok
    end

    project_ids
  end
end
