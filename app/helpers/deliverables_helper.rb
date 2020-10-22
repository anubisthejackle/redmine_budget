# coding: utf-8
module DeliverablesHelper
  include RedmineBudget
  include IssuesHelper

  CALCULATOR_FIELDS_WITHOUT_RESULT = [:type, :cost_per_hour]
  CALCULATOR_FIELDS_WITHOUT_INPUT = [:budget]
  DELIVERABLE_ATTRIBUTES = [:status, :due]

  def deliverable_overview(deliverable)
    content_tag(:table) {
      content_tag(:tr) {
        content_tag(:td, class: 'overview-links') {
          if allowed_management?
            concat link_to(l(:button_edit), action: 'edit', id: deliverable.id)
            concat link_to(l(:button_delete), deliverable_path(deliverable.id),
                           confirm: l(:text_are_you_sure), method: :delete)
            concat link_to(l(:button_copy), copy_deliverable_path(deliverable))
          end
          concat link_to(l(:label_issue_plural), deliverable_issues_path(deliverable.id))
          if allowed_management? && @project && @project.versions.length > 0
            concat content_tag(:div) {
              concat select_tag("version_assign_#{deliverable.id}",
                                options_from_collection_for_select(@project.versions.sort, 'id', 'name'),
                                prompt: "-- #{l(:label_version)} --",
                                class: 'deliverable-version-assign',
                                'data-url' => deliverable_assign_issues_path(deliverable_id: deliverable.id))
            }
          end
        } + \
        content_tag(:td, class: 'overview-total-time') {
          content_tag(:fieldset) {
            concat content_tag(:legend, l(:label_total_time))
            concat content_tag(:table, class: 'deliverable-overview-time') {
              concat content_tag(:tr) {
                concat content_tag(:td, l(:field_estimated_hours))
                concat content_tag(:td, hours(deliverable.estimated_hours))
              }
              concat content_tag(:tr) {
                concat content_tag(:td, l(:label_spent_time))
                concat content_tag(:td, hours(deliverable.spent_hours))
              }
            }
            concat deliverable_assigns(deliverable.members,
                                       table: { class: 'delvierable-overview-assigns' })
          }
        } + \
        content_tag(:td, class: 'overview-budget') {
          content_tag(:fieldset) {
            concat content_tag(:legend, l(:field_budget))
            concat deliverable_budget(deliverable)
          }
        } + \
        content_tag(:td, class: 'overview-issues') {
          content_tag(:fieldset) {
            concat content_tag(:legend) {
              link_to l(:label_x_issues, count: deliverable.issues.length),
                      deliverable_issues_path(deliverable.id)
            }
            concat content_tag(:table, class: 'deliverable-overview-issues') {
              deliverable.issues.group_by(&:tracker).each do |tracker, issues|
                concat content_tag(:tr) {
                  content_tag(:td, tracker.name) + content_tag(:td, issues.length)
                }
              end
            }
          }
        }
      }
    }
  end

  def deliverable_budget(deliverable)
    content_tag(:dl, class: 'deliverable-attributes') {
      if deliverable.hourly?
        concat content_tag(:dt, l(:field_cost_per_hour))
        concat content_tag(:dd, currency(deliverable.cost_per_hour))

        concat content_tag(:dt, l(:field_total_hours))
        concat content_tag(:dd, hours(deliverable.total_hours))
      end

      if deliverable.fixed?
        concat content_tag(:dt, l(:field_fixed_cost))
        concat content_tag(:dd, currency(deliverable.fixed_cost))
      end

      [:overhead, :materials, :profit, :budget].each do |field|
        concat content_tag(:dt, l("field_#{field}"))
        concat content_tag(:dd, currency(deliverable.send(field)))
      end
    }
  end

  def deliverable_activities_select(member = nil)
    select_tag('deliverable[assigns_attributes][][activity_id]',
               options_from_collection_for_select(DeliverableAssign.activities, 'id', 'name', (member.try(:activity_id))),
                                                  id: '', class: 'activity',
                                                  include_blank: true,
                                                  data: { name: 'activity' })
  end

  def deliverable_assign_user(assign)
    if assign.user
      if User.current.allowed_to_globally?({ controller: 'users', action: 'show' }, {})
        link_to(assign.user, assign.user)
      else
        assign.user
      end
    end
  end

  def deliverable_assign_info(assign)
    concat content_tag(:span, hours(assign.spent_hours),
                       title: l(:label_spent_time))
    concat ' / '
    content_tag(:span, hours(assign.assigned_hours),
                title: l(:label_assigned_hours))
  end

  def deliverable_assign_activity(assign)
    if assign.activities
      assign.activities.map(&:name).join(', ')
    else
      assign.activity
    end
  end

  def deliverable_assigns(assigns, opts = {})
    opts[:table] ||= { class: 'list' }

    if assigns.any?
      content_tag(:table, opts[:table]) {
        content_tag(:tbody) {
          assigns.each do |assign|
            concat content_tag(:tr) {
              concat content_tag(:td, deliverable_assign_user(assign))
              concat content_tag(:td, deliverable_assign_activity(assign))
              concat content_tag(:td) { concat deliverable_assign_info(assign) }
              concat content_tag(:td) { currency(assign.cost) }
            }
          end
        }
      }
    else
      ''
    end
  end

  def deliverable_assign_progress_title
    l(:caption_deliverable_assign_progress)
  end

  def deliverable_issues(issues)
    s = '<form><table class="list issues">'
    issue_list(issues.visible.sort_by(&:lft)) do |child, level|
      css = "issue issue-#{child.id}"
      css << " idnt idnt-#{level}" if level > 0
      s << content_tag(:tr,
             content_tag(:td, link_to_issue(child, truncate: 60, project:  (child.project_id != child.project_id)), class: 'subject') +
             content_tag(:td, h(child.status)) +
             content_tag(:td, link_to_user(child.assigned_to)) +
             content_tag(:td, progress_bar(child.done_ratio, width: '80px'), title: l(:caption_deliverable_issue_progress)),
             class: css)
    end
    s << '</table></form>'
    s.html_safe
  end

  def deliverable_attribute_rows(deliverable)
    attributes = []

    DELIVERABLE_ATTRIBUTES.each do |name|
      attributes << [ l("label_#{name}"), deliverable.send(:name) ]
    end

    @deliverable.custom_field_values.each do |cv|
      attributes << [cv.custom_field.name, cv.value]
    end

    attributes.each_slice(2) do |a, b|
      concat a
    end
  end

  def deliverable_field(name, &block)
    c = ['deliverable_field']

    c << 'deliverable_field-disabled' unless field_editable?(name)

    content_tag(:div, id: "deliverable_field-#{name}", class: c) { yield }
  end

  def field_editable?(name)
    name = name.to_s
    @_is_supervisor ||= User.current.is_or_belongs_to?(Settings.supervisor_group) \
                        || User.current.admin?

    !@deliverable.protected?(name) or @_is_supervisor
  end

  def protected_fields_classes
    c = []

    @deliverable.protected_fields.each do |field|
      c << "#deliverable_field-#{field}" unless field_editable?(field)
    end

    c
  end

  def currency(value=0, precision=0)
    number_to_currency(value, precision: precision)
  end

  def calculator_row(field, kind = :text, opts = {})
    content_tag(:tr) {
      concat content_tag(:th) {
        label(:deliverable, field, opts[:label])
      }
      concat content_tag(:td) {
        next if CALCULATOR_FIELDS_WITHOUT_INPUT.include?(field)

        # if send via #calculator, display raw input
        if params[:deliverable] and params[:deliverable][:budget_attributes]
          value = params[:deliverable][:budget_attributes][field]
        elsif @deliverable.read_attribute("#{field}_percent")
          value = @deliverable.read_attribute("#{field}_percent").to_s + '%'
        else
          value = @deliverable.read_attribute(field)
        end

        value = nil if value == 0

        case kind
        when :text
          text_field_tag("deliverable[budget_attributes][#{field}]", value, size: 7)
        when :checkbox
          check_box(:deliverable, field, {}, *opts.fetch(:options, []))
        end
      }

      if CALCULATOR_FIELDS_WITHOUT_RESULT.include?(field)
        result = nil
      else
        if field == :total_hours
          result = @deliverable.cost_per_hour * @deliverable.total_hours
        else
          result = @deliverable.send(field)
        end
        result = nil if result == 0
      end

      concat content_tag(:td, currency(result, 2), class: 'deliverable-calculator-result')
    }
  end

  def calculator(deliverable)
    content_tag(:table, class: 'deliverable-calculator') {
      concat calculator_row(:type, :checkbox,
                            label: l(:label_fixed_cost),
                            options: Deliverable::TYPES)

      if deliverable.hourly?
        concat calculator_row(:cost_per_hour)
        concat calculator_row(:total_hours)
      end

      if deliverable.fixed?
        concat calculator_row(:fixed_cost)
      end

      concat calculator_row(:overhead)
      concat calculator_row(:materials)
      concat calculator_row(:profit)
      concat calculator_row(:budget)
    }
  end

  def can_unlock?(user = User.current)
    supervisor_group = Settings.supervisor_group
    user.admin? or supervisor_group && User.is_or_belongs_to?(supervisor_group)
  end

  def hours(value, suffix = false)
    i = number_with_precision(value, precision: 0, significant: true)

    suffix ? "#{i} h" : i
  end

  def hours_field(name, value, opts)
    text_field_tag(name, hours(value), opts)
  end

  def number_or_percent_field(object, number_field, percent_field, default_value, options)
    # Build a text_field by hand named after the number field but with the percent_field and % as the value
    return text_field_tag('deliverable_' + number_field.to_s,
                          object.read_attribute(percent_field).to_s + "%",
                          options.merge({ :name => "deliverable[#{number_field.to_s}]"})) unless object.read_attribute(percent_field).blank?

    # Number and fallback with no values
    value = object.read_attribute(number_field) || default_value || ''
    return text_field(:deliverable, number_field, options.merge({ :value => value}))
  end

  # Check if the current user is allowed to manage the budget.  Based on Role permissions.
  def allowed_management?
    return User.current.allowed_to?(:manage_budget, @project) || @project.nil?
  end

  def overview_column?
    @budget_overview_block ||= @query.column_names.include?(:overview)
  end


  def sidebar_queries

    @sidebar_queries ||= DeliverableQuery.visible
                           .order("#{Query.table_name}.name ASC")
                           .where(@project.nil? ?
                                    ["project_id IS NULL"] :
                                    ["project_id IS NULL OR project_id = ?", @project.id])
                           .to_a
  end

  def query_links(title, queries)
    return '' if queries.empty?
    # links to #index on issues/show
    url_params = { controller: 'deliverables', action: 'index', project_id: @project.try(:id) }

    content_tag('h3', title) + "\n" +
      content_tag('ul',
        queries.collect {|query|
            css = 'query'
            css << ' selected' if query == @query
            content_tag('li', link_to(query.name, url_params.merge(:query_id => query), :class => css))
          }.join("\n").html_safe,
        :class => 'queries'
      ) + "\n"
  end

  def render_sidebar_queries
    out = ''.html_safe
    out << query_links(l(:label_my_queries), sidebar_queries.select(&:is_private?))
    out << query_links(l(:label_query_plural), sidebar_queries.reject(&:is_private?))
    out
  end
end
