class DeliverableStatus < ActiveRecord::Base
  PROTECTED_FIELDS = {
    subject: 'subject',
    description: 'description',
    status_id: 'status',
    budget_attributes: 'budget',
    assigns_attributes: 'assigns'
  }

  acts_as_list

  has_many :deliverables, foreign_key: 'status_id', dependent: :nullify
  has_many :workflow_rules, class_name: 'DeliverableWorkflowRule',
           foreign_key: 'old_status_id', dependent: :delete_all

  scope :sorted, lambda { order(:position) }

  validates :name, presence: true

  serialize :protected_fields, Array

  before_save :select_protected_fields
  before_save :update_workflow_rules
  after_save :update_default

  def self.default
    order('is_default DESC, position').first
  end

  def closed?
    is_closed
  end

  def protected?(field = nil)
    field ? protected_fields.include?(field.to_s) : protected_fields.any?
  end

  def workflow_rules_attributes=(attrs)
    @new_workflow_rules = []

    attrs.each do |attr|
      next unless attr.include?(:_enabled)

      rule = DeliverableWorkflowRule.new
      rule.role_id = attr[:role_id]
      rule.old_status = self
      rule.new_status_id = attr[:new_status_id]

      @new_workflow_rules << rule
    end
  end

  def others
    self.class.all - [self]
  end

  def new_status?(role_id, new_status_id)
    return true if new_record?

    @workflow_rules_grouped ||= workflow_rules.group(:role_id, :new_status_id)
                                  .map { |r| [ r.role_id, r.new_status_id ] }

    @workflow_rules_grouped.include?([role_id, new_status_id])
  end

  def to_s
    name
  end

  private

  def select_protected_fields
    # Prevent exception in migration #15 when protected_fields
    # weren't implemented.
    return unless respond_to?(:protected_fields)

    allowed_fields = PROTECTED_FIELDS.keys.map(&:to_s)

    self.protected_fields = protected_fields
                              .select { |a| allowed_fields.include?(a) }
  end

  def update_workflow_rules
    self.workflow_rules = @new_workflow_rules if @new_workflow_rules
  end

  def update_default
    return unless is_default?

    DeliverableStatus.where(['id <> ?', id])
      .update_all({ is_default: false })
  end
end
