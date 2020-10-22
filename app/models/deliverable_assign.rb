class DeliverableAssign < ActiveRecord::Base
  belongs_to :deliverable
  belongs_to :activity, class_name: 'Enumeration'
  belongs_to :user

  validates :activity_id, presence: true
  validates :hours, numericality: { greater_than_or_equal_to: 0 }

  before_save :check_activity

  # Used in Deliverable#members
  attr_accessor :activities

  def self.activities
    TimeEntryActivity.active.sorted
  end

  def self.users_for_project(project)
    excluded_group = Group.includes(:users).find_by_id(excluded_group) if excluded_group
    users = User.member_of(project).all

    if excluded_group
      users.select! { |u| !u.is_or_belongs_to?(excluded_group) }
    end

    users
  end

  def subject
    user || activity
  end

  def progress
    assigned_hours > 0 ? (spent_hours / assigned_hours) * 100 : 0
  end

  def assigned_hours
    @assigned_hours || hours || 0
  end

  attr_writer :assigned_hours

  def spent_hours
    @spent_hours ||= TimeEntry.where(issue_id: deliverable.issues.pluck(:id),
                                     user_id: user_id).sum(:hours)
  end

  attr_writer :spent_hours

  def cost
    @cost ||= TimeEntry.joins(issue: :custom_values)
                .where(time_entries: { user_id: user_id })
                .where(custom_values: { custom_field_id: RedmineBudget.cf_ids,
                                        value: deliverable_id })
                .sum(:cost)
  end

  attr_writer :cost

  private

  def check_activity
    self.activity_id = nil if not self.class.activities.pluck(:id).include?(activity_id)
  end
end
