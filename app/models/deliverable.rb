class Deliverable < ActiveRecord::Base
  include RedmineBudget
  include Redmine::SafeAttributes

  TYPES = [
    'FixedDeliverable',
    'HourlyDeliverable'
  ]

  BUDGET_ATTRIBUTES = [
    'cost_per_hour',
    'total_hours',
    'profit',
    'overhead',
    'materials',
    'fixed_cost'
  ]

  # Budget attributes should be set using #budget_attributes=
  attr_protected *BUDGET_ATTRIBUTES

  belongs_to :project
  has_many :assigns, class_name: 'DeliverableAssign',
           foreign_key: 'deliverable_id', dependent: :destroy
  belongs_to :status, class_name: 'DeliverableStatus',
             foreign_key: 'status_id'

  validates :subject, presence: true

  validate :check_project_change

  before_destroy :remove_issue_relations

  acts_as_customizable

  acts_as_attachable view_permission: :view_budget,
                     delete_permission: :manage_budget

  # Redmine 2.x doesn't accept :edit_permission option
  if Redmine::VERSION::MAJOR >= 3
    self.attachable_options[:edit_permission] = :manage_budget
  end

  accepts_nested_attributes_for :assigns, allow_destroy: true,
                                reject_if: proc { |a| !a[:hours].to_i || a[:activity_id].blank? }

  scope :visible, lambda {
    joins(:project)
      .where(Project.allowed_to_condition(User.current, :view_budget))
  }

  scope :settable, lambda { |project|
    if User.current.allowed_to?(:view_budget, project) \
      or User.current.allowed_to?(:set_deliverable, project)
      where(project_id: project.id)
    else
      all
    end
  }

  scope :active, lambda {
    joins(:status).where(deliverable_statuses: { is_closed: false })
  }

  before_save :populate_calculation

  delegate :closed?, to: :status, allow_nil: true
  delegate :protected?, to: :status, allow_nil: true
  delegate :protected_fields, to: :status, allow_nil: true

  BUDGET_ATTRIBUTES.each do |name|
    define_method(name) { super() || 0 }
  end

  def issues
    Issue.joins(:custom_values)
      .where(project_id: project_id)
      .where(custom_values: { custom_field_id: RedmineBudget.cf_ids, value: self.id })
  end

  def copy
    duped_assigns = assigns.map { |a| a.dup.tap { |b| b.deliverable = nil } }

    self.dup.tap do |d|
      d.custom_field_values = self.custom_field_values.inject({}) { |h, v| h[v.custom_field_id] = v.value; h }
      d.assigns = duped_assigns
      d.status = DeliverableStatus.default
    end
  end

  def copy?
    @copied_from.present?
  end

  def assign_issues_by_version(version_id)
    version = Version.find(version_id)
    cf = RedmineBudget.custom_field

    return 0 if cf.blank? or version.fixed_issues.blank?

    issues = version
               .fixed_issues
               .where(tracker_id: cf.trackers.pluck(:id))
               .includes(custom_values: :custom_field)
               .includes(:project, :tracker)

    issues.each do |issue|
      issue.custom_field_values = { cf.id => self.id }
      issue.save_custom_field_values
    end

    issues.length
  end

  # Change the Deliverable type to another type. Valid types are
  #
  # * FixedDeliverable
  # * HourlyDeliverable
  def change_type(to)
    if [FixedDeliverable.name, HourlyDeliverable.name].include?(to)
      self.type = to
      self.save!
      return Deliverable.find(self.id)
    else
      return self
    end
  end

  def allowed_statuses(user = User.current)
    if User.current.admin? or user.is_or_belongs_to?(Settings.supervisor_group)
      roles = Role.all
    else
      roles = user.roles_for_project(project)
    end

    initial_status = status || DeliverableStatus.default

    statuses = DeliverableWorkflowRule.includes(:new_status)
                 .where(old_status_id: initial_status.id,
                        role_id: roles.map(&:id)).map(&:new_status)
                 .compact
                 .uniq


    statuses << initial_status unless statuses.include?(initial_status)

    statuses.sort!

    statuses
  end

  # Adjusted score to show the status of the Deliverable.  Will range from 100
  # (everything done with no money spent) to -100 (nothing done, all the money spent)
  def score
    progress - budget_ratio
  end

  # Amount of money spent on the issues.  Determined by the Member's rate and
  # timelogs.
  def spent
    @spent ||= time_sums[:cost] || 0.0
  end

  # Number of hours used.
  def spent_hours
    time_sums[:hours] || 0.0
  end

  def estimated_hours
    @estimated_hours ||= issues
                           .where('issues.root_id = issues.id')
                           .sum(:estimated_hours)
  end

  def expenses
    overhead + materials
  end

  # Percentage of the deliverable process based on the progress of the
  # assigned issues.
  def progress
    return @progress unless @progress.nil?

    # Array of counts: [ closed_issues, open_issues ]
    i = issues.select('closed_on IS NULL').group('closed_on IS NULL')
        .order('closed_on IS NULL').count.values

    return 0 if i.length != 2

    @progress = (i.first * 100) / i.sum
  end

  attr_writer :progress

  # Amount of the budget spent.  Expressed as as a percentage whole number
  def budget_ratio
    return 0.0 if self.budget.nil? || self.budget == 0.0
    return ((self.spent / self.budget) * 100).round
  end

  def overhead
    return read_attribute(:overhead) unless read_attribute(:overhead).nil?
    return ((read_attribute(:overhead_percent).to_f / 100.0) * self.labor_budget) unless read_attribute(:overhead_percent).nil?
    return 0
  end

  def budget_attributes=(params)
    params.each do |key, value|
      next unless BUDGET_ATTRIBUTES.include?(key)

      write_percent_or_number(key, value)
    end
  end

  # Wrap the budget getter so it returns 0 if budget is nil
  def budget
    read_attribute(:budget) || 0
  end

  # Amount of the budget remaining to be spent
  def budget_remaining
    budget - spent
  end

  alias_method :left, :budget_remaining

  def time_sums
    @time_sums ||= TimeEntry.select("SUM(cost) AS cost, SUM(hours) as hours")
                 .where(issue_id: issues.pluck(:id))
                 .first.attributes.symbolize_keys
  end

  def time_sums=(value)
    @time_sums = value || { cost: 0.0, hours: 0.0 }
  end

  # Amount spent over the total budget
  def overruns
    if self.left >= 0
      return 0
    else
      return self.left * -1
    end
  end

  # Budget of labor, without counting profit or overheads
  def labor_budget
    0
  end

  # Returns true if the deliverable can be edited by user, otherwise false
  def editable?(user = User.current)
    user.admin? or user.allowed_to?(:manage_budget, project)
  end

  def visible?(user = User.current)
    user.admin? or user.allowed_to?(:view_budget, self.project)
  end

  def fixed?
    self.class == FixedDeliverable
  end

  def hourly?
    self.class == HourlyDeliverable
  end

  def name
    subject
  end

  def to_s
    subject
  end

  # Need to override this to make it work with inherited models
  def available_custom_fields
    CustomField.where("type = 'DeliverableCustomField'").sorted.all
  end

  def members
    mems = []
    times = TimeEntry
              .select('custom_values.value AS deliverable_id, user_id, SUM(hours) AS spent_hours, SUM(cost) AS cost')
              .joins(issue: :custom_values)
              .where(project_id: project_id)
              .where(custom_values: { custom_field_id: RedmineBudget.cf_ids, value: self.id })
              .group(:user_id)
    user_mem = {}

    assigns.each do |assign|
      user_id = assign.user_id

      if user_id.nil?
        mems << assign

        next
      end

      member = user_mem[user_id]

      if member.nil?
        member = DeliverableAssign.new(user: assign.user,
                                       deliverable: self)
        member.activities = []
        member.assigned_hours = 0

        user_mem[member.user_id] = member
      end

      member.activities << assign.activity
      member.assigned_hours += assign.hours
    end

    times.each do |a|
      user_id = a[:user_id]
      member = user_mem[user_id]

      if member.nil?
        member = DeliverableAssign.new(user_id: a[:user_id],
                                       deliverable: self)
        member.activities = []
        member.assigned_hours = 0

        mems << member
      end

      member.spent_hours = a[:spent_hours]
      member.cost = a[:cost]
    end

    mems += user_mem.values

    mems
  end

  def allowed_target_projects(user = User.current)
    return [] if new_record? or persisted? && issues.any?

    cond = Project.has_module(:budget)
             .allowed_to_condition(user, :manage_budget)

    if project
      cond = ["(#{cond}) OR #{Project.table_name}.id = ?", project.id]
    end

    Project.where(cond)
  end

  private

  def write_percent_or_number(attribute, value)
    value = value.to_s.strip.gsub(',', '.')
    percent_name = "#{attribute}_percent"

    if value.ends_with?('%') and attribute_names.include?(percent_name)
      value = value.to_i

      case attribute
      when 'overhead' then factor = labor_budget
      when 'materials' then factor = labor_budget + overhead
      else factor = budget
      end

      write_attribute(attribute, (value * factor) / 100)
      write_attribute(percent_name, value)
    else
      write_attribute(percent_name, nil) if read_attribute(percent_name)
      write_attribute(attribute, value.to_f)
    end
  end

  def use_issue_status_for_done_ratios?
    return defined?(Setting.issue_status_for_done_ratio?) && Setting.issue_status_for_done_ratio?
  end

  def populate_calculation
    write_attribute(:budget, budget)
  end

  def remove_issue_relations
    CustomValue.where(custom_field_id: RedmineBudget.cf_ids,
                      value: id).update_all(value: nil)
  end

  # Ensure that project cannot be changed if there are issues associated
  def check_project_change
    if persisted? and allowed_target_projects.include?(project) and issues.any?
      errors.add :project
    end
  end
end
