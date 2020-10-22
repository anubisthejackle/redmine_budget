# Budget is a meta class that is used to calculate summary data
# for all the deliverables on a project.  Think of it akin to:
#  has_many :deliverables
#  belongs_to :project
#
class Budget
  attr_reader :project

  def initialize(project_id)
    @project = Project.find(project_id)
  end

  def next_due_date
    deliverables.select(:due).order('due ASC').first.try(:due)
  end

  def final_due_date
    deliverables.select(:due).order('due DESC').first.try(:due)
  end

  def sums
    @sums ||= Deliverable.select("SUM(budget) AS budget, \
SUM(CASE type WHEN 'HourlyDeliverable' THEN cost_per_hour * total_hours ELSE fixed_cost END) AS labor_budget
").where(project_id: @project.id).first.attributes.symbolize_keys
  end

  def deliverables
    Deliverable.where(project_id: @project.id)
  end

  def issues
    Issue.joins(:custom_values)
      .where(project_id: project.id)
      .where(custom_values: { custom_field_id: RedmineBudget.cf_ids, value: deliverables.pluck(:id) })
  end

  def budget
    sums[:budget] || 0
  end

  def labor_budget
    sums[:labor_budget] || 0
  end

  # Amount of the budget spent.  Expressed as as a percentage whole number
  def budget_ratio
    if budget > 0.0
      return ((self.spent / budget) * 100).round
    else
      self.progress
    end
  end

  # Total amount spent for all the deliverables
  def spent
    @spent ||= TimeEntry.joins(issue: :custom_values)
             .where(issues: { project_id: @project.id },
                    custom_values: { custom_field_id: RedmineBudget.cf_ids })
             .sum(:cost)
  end

  # Amount of budget left on the deliverables
  def left
    budget - spent
  end

  # Amount of labor budget left on the deliverables
  def labor_budget_left
    labor_budget - spent
  end

  # Amount spent over the budget
  def overruns
    left >= 0 ? 0 : left * -1
  end

  # Completation progress, expressed as a percentage whole number
  def progress
    return 100 unless self.deliverables.size > 0
    return 100 if self.budget == 0.0

    balance = 0.0

    self.deliverables.each do |deliverable|
      balance += deliverable.budget * deliverable.progress
    end

    return (balance / self.budget).round
  end

  # Budget score.  Will range from 100 (everything done with no money spent) to -100 (nothing done, all the money spent)
  def score
    progress - budget_ratio
  end

  # Total profit of the deliverables.  This is *not* calculated based on the amount
  # spent and total budget but is the total of the profit amount for the deliverables.
  def profit
    return 0.0 unless self.deliverables.size > 0

    # Covers fixed and percentage profit though the +profit+ method being overloaded on the Deliverable types
    return self.deliverables.collect(&:profit).delete_if { |d| d.blank?}.inject { |sum, n| sum + n } || 0.0
  end

  # Dollar amount of time that has been logged to the project itself
  def amount_missing_on_issues
    TimeEntry.where(project_id: project.id, issue_id: nil).sum(:cost)
  end

  # Dollar amount of time that has been logged to issues that are not assigned to deliverables
  def amount_missing_on_deliverables
    TimeEntry.joins(:issue)
      .where(issues: { project_id: project.id })
      .where('issues.id NOT IN (?)', issues.pluck(:id))
      .sum(:cost)
  end
end
