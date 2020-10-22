class HourlyDeliverable < Deliverable
  def self.model_name
    Deliverable.model_name
  end

  def budget
    (cost_per_hour * total_hours) + expenses + profit
  end

  def profit
    if read_attribute(:profit_percent).nil?
      return super
    else
      return 0.0 if read_attribute(:cost_per_hour).nil? || read_attribute(:total_hours).nil?
      labor = (read_attribute(:cost_per_hour) * read_attribute(:total_hours))

      return (read_attribute(:profit_percent).to_f / 100.0) * (labor + self.overhead)
    end
  end

  # Rembmer to update Budget#sums
  def labor_budget
    (cost_per_hour.to_f * total_hours.to_f) || 0.0
  end
end
