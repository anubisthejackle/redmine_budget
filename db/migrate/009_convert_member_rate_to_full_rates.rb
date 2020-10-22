class ConvertMemberRateToFullRates < ActiveRecord::Migration
  def self.up
    # Add a new Rate object for each Member
    Member.where('rate IS NOT NULL').each do |member|
      say_with_time "Converting rate for #{member.user.to_s} - #{member.project.to_s}" do
        # Need to find the first date for any TimeEntries  #1924
        first_time_entry = TimeEntry.find(:first,
                                          :conditions => ['project_id = (?) AND user_id = (?)', member.project_id, member.user_id],
                                          :order => 'spent_on ASC')
        date_in_effect = first_time_entry.spent_on if first_time_entry
        date_in_effect ||= member.created_on

        rate = Rate.new({
                          :user => member.user,
                          :amount => member.rate,
                          :project => member.project,
                          :date_in_effect => date_in_effect
                        })
        rate.save!
      end
    end

  end
end
