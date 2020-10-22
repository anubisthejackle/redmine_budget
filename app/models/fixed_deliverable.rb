class FixedDeliverable < Deliverable
  def self.model_name
    Deliverable.model_name
  end

  # Budget is managed by contractor hance it shouldn't be scored.
  def score
    0
  end

  def budget
    fixed_cost + expenses + profit
  end

  def spent
    return 0.0 if self.fixed_cost.nil?

    fixed_cost.to_f + super()
  end

  def profit
    if read_attribute(:profit_percent).nil?
      super
    else
      (read_attribute(:profit_percent).to_f / 100.0) * (read_attribute(:fixed_cost).to_f + overhead)
    end
  end

  def labor_budget
    fixed_cost || 0.0
  end
end
