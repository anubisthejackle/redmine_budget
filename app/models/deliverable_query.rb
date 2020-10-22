class DeliverableQuery < Query
  self.queried_class = Deliverable

  self.available_columns = [
    QueryColumn.new(:id, sortable: "#{Deliverable.table_name}.id", default_order: 'desc', caption: '#', frozen: true),
    QueryColumn.new(:status, sortable: "#{DeliverableStatus.table_name}.status"),
    QueryColumn.new(:subject, sortable: "#{Deliverable.table_name}.subject"),
    QueryColumn.new(:estimated_hours),
    QueryColumn.new(:spent_hours, caption: :label_spent_time),
    QueryColumn.new(:profit, sortable: "#{Deliverable.table_name}.profit"),
    QueryColumn.new(:overhead, sortable: "#{Deliverable.table_name}.overhead"),
    QueryColumn.new(:materials, sortable: "#{Deliverable.table_name}.materials"),
    QueryColumn.new(:cost_per_hour, sortable: "#{Deliverable.table_name}.materials"),
    QueryColumn.new(:total_hours, sortable: "#{Deliverable.table_name}.total_hours"),
    QueryColumn.new(:project, sortable: "#{Project.table_name}.name", groupable: true),
    QueryColumn.new(:budget, sortable: "#{Deliverable.table_name}.budget"),
    QueryColumn.new(:labor_budget, caption: :caption_labor_budget),
    QueryColumn.new(:spent, caption: :caption_spent),
    QueryColumn.new(:due, sortable: "#{Deliverable.table_name}.due"),
    QueryColumn.new(:progress, caption: :caption_progress),
    QueryColumn.new(:score, sortable: "#{Deliverable.table_name}.score", caption: :caption_score),
    QueryColumn.new(:description, inline: false),
    QueryColumn.new(:overview, inline: false, caption: :label_overview)
  ]

  scope :visible, lambda {|*args|
    user = args.shift || User.current
    base = Project.allowed_to_condition(user, :view_budget, *args)

    if column_names.include?('visibility')
      scope = joins("LEFT OUTER JOIN #{Project.table_name} ON #{table_name}.project_id = #{Project.table_name}.id").
                where("#{table_name}.project_id IS NULL OR (#{base})")

      if user.admin?
        scope.where("#{table_name}.visibility <> ? OR #{table_name}.user_id = ?", VISIBILITY_PRIVATE, user.id)
      elsif user.memberships.any?
        scope.where("#{table_name}.visibility = ?" +
                    " OR (#{table_name}.visibility = ? AND #{table_name}.id IN (" +
                    "SELECT DISTINCT q.id FROM #{table_name} q" +
                    " INNER JOIN #{table_name_prefix}queries_roles#{table_name_suffix} qr on qr.query_id = q.id" +
                    " INNER JOIN #{MemberRole.table_name} mr ON mr.role_id = qr.role_id" +
                    " INNER JOIN #{Member.table_name} m ON m.id = mr.member_id AND m.user_id = ?" +
                    " WHERE q.project_id IS NULL OR q.project_id = m.project_id))" +
                    " OR #{table_name}.user_id = ?",
                    VISIBILITY_PUBLIC, VISIBILITY_ROLES, user.id, user.id)
      elsif user.logged?
        scope.where("#{table_name}.visibility = ? OR #{table_name}.user_id = ?", VISIBILITY_PUBLIC, user.id)
      else
        scope.where("#{table_name}.visibility = ?", VISIBILITY_PUBLIC)
      end
    else
      user_id = user.logged? ? user.id : 0

      includes(:project).where("(#{table_name}.project_id IS NULL OR (#{base})) AND (#{table_name}.is_public = ? OR #{table_name}.user_id = ?)", true, user_id)
    end
  }


  def initialize(attributes=nil, *args)
    super(attributes)
    self.filters ||= {}
  end

  # Returns true if the query is visible to +user+ or the current user.
  def visible?(user=User.current)
    (project.nil? || user.allowed_to?(:view_budget, project))
  end

  # Returns the deliverables
  # Valid options are :order, :offset, :limit, :include, :conditions
  def deliverables(options={})
    order_option = [group_by_sort_order, options[:order]].flatten.reject(&:blank?)
    scope = Deliverable
            .visible
            .where(statement)
            .includes(([:project, :assigns] + (options[:include] || [])).uniq)
            .where(options[:conditions])
            .order(order_option)
            .joins(joins_for_order_statement(order_option.join(',')))
            .limit(options[:limit])
            .offset(options[:offset])

    if options[:cache]
      cache_time(scope)
      cache_progress(scope)
    end

    scope
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  def deliverable_count
    deliverables.count
  end

  def initialize_available_filters
    add_available_filter 'status_id', :type => :list_status,
                         values: DeliverableStatus.sorted.all.map { |p| [p.name, p.id.to_s] }
    add_available_filter 'budget', :type => :float
    add_available_filter 'overhead', :type => :float
    add_available_filter 'total_hours', :type => :float
    add_available_filter 'overhead', :type => :float
    add_available_filter 'due', :type => :date
    add_available_filter 'project_id', :type => :list,
                         :values => User.current.projects.collect { |p| [p.name, p.id.to_s] }

    if project.nil?
      deliverables = Deliverable.active.includes(:project).visible.group_by(&:project)
      deliverables = deliverables.map { |k, v| [k, v] }.flatten

      values = []
      values << ["<< #{l(:label_any).downcase} >>", '*']

      deliverables.each do |o|
        values << [o.name, (o.is_a?(Project) ? "p_#{o.id}" : o.id.to_s)]
      end

      add_available_filter 'deliverable_id', type: :list, values: values
    end

    add_custom_fields_filters(custom_fields(is_filter: true))
  end

  def available_columns
    return @available_columns unless @available_columns.nil?

    @available_columns = self.class.available_columns.dup
    @available_columns += custom_fields.map { |cf| QueryCustomFieldColumn.new(cf) }

    @available_columns
  end

  def default_columns_names
    @default_columns_names ||= RedmineBudget::Settings.list_default_columns.map(&:to_sym)
  end

  ##
  # If selected columns are equal to default ones then Query#colum_names
  # returns nil which makes Query#has_column? always false.
  # This behaviour is unwanted since "Show" checkboxes will not by checked
  # for block columns that was defined as default in plugin settings.
  def column_names
    super || default_columns_names
  end

  def has_default_columns?
    false
  end

  def sql_for_deliverable_id_field(field, operator, value)
    return if value.include?('*')
    '(' + sql_for_field('id', operator, value, Deliverable.table_name, 'id', false) + ')'
  end

  def sql_for_status_id_field(field, operator, value)
    case operator
    when 'o'
      sql = "#{queried_table_name}.status_id IN (SELECT id FROM #{DeliverableStatus.table_name} WHERE is_closed=#{connection.quoted_false})"
    when 'c'
      sql = "#{queried_table_name}.status_id IN (SELECT id FROM #{DeliverableStatus.table_name} WHERE is_closed=#{connection.quoted_true})"
    else
      sql_for_field(field, operator, value, queried_table_name, field)
    end
  end

  %w(project_manager_signoff client_signoff).each do |name|
    define_method "sql_for_#{name}_field" do |field, operator, value|
      op = (operator == "=" ? 'IN' : 'NOT IN')
      va = value.map {|v| v == '0' ? connection.quoted_false : connection.quoted_true}.uniq.join(',')

      "#{Deliverable.table_name}.#{name} #{op} (#{va})"
    end
  end

  def is_private?
    !is_public?
  end

  def is_public?
    visibility == VISIBILITY_PRIVATE
  rescue
    super
  end

  private

  def custom_fields(cond = {})
    cfs = DeliverableCustomField.where(cond)

    if project
      cfs = cfs.joins('INNER JOIN custom_fields_projects ' \
                      'ON custom_fields_projects.custom_field_id = ' \
                      "#{IssueCustomField.table_name}.id").all
    end

    cfs
  end

  def cache_time(deliverables)
    i = {}
    ts = TimeEntry.select("custom_values.value AS deliverable_id, SUM(cost) AS cost, SUM(hours) AS hours")
         .joins(issue: :custom_values)
         .where(custom_values: { custom_field_id: RedmineBudget.cf_ids, value: deliverables.map(&:id) })
         .group('custom_values.value').map(&:attributes)

    ts.each do |t|
      deliverable_id, cost_sum, hours_sum = t['deliverable_id'].to_i, t['cost'], t['hours']

      i[deliverable_id] = { cost: cost_sum, hours: hours_sum }
    end

    deliverables.each { |d| d.time_sums = i[d.id] }
  end

  def cache_progress(deliverables)
    deliverable_ids = deliverables.map(&:id)

    i = Issue
          .select('custom_values.value AS deliverable_id, closed_on IS NOT NULL AS is_closed, COUNT(*) as count')
          .joins(:custom_values)
          .where(custom_values: { custom_field_id: RedmineBudget.cf_ids, value: deliverable_ids })
          .group('custom_values.value, closed_on IS NOT NULL')
          .order('custom_values.value, closed_on IS NOT NULL')
          .map(&:attributes)
          .group_by { |a| a['deliverable_id'].to_i }

    deliverables.each do |deliverable|
      t = i[deliverable.id]

      deliverable.progress = 0 and next if t.nil?

      case t.length
      when 2
        open, closed = t.first['count'], t.last['count']
      when 1
        if t.first['is_closed'] == 0
          open, closed = t.first['count'], 0
        else
          open, closed = 0, t.first['count']
        end
      else
        deliverable.progress = 0
        next
      end

      deliverable.progress = ((closed / (open + closed).to_f) * 100).to_i
    end

    i
  end

  private

  def connection
    self.class.connection
  end
end
