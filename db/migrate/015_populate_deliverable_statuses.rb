class PopulateDeliverableStatuses < ActiveRecord::Migration
  DEFAULT_STATUSES = {
    new: { is_closed: false, is_protected: false, is_default: true },
    in_progress: { is_closed: false, is_protected: true },
    closed: { is_closed: true, is_protected: true },
  }

  def up
    DEFAULT_STATUSES.each do |name, attributes|
      label = I18n.t("default_issue_status_#{name}")

      DeliverableStatus.create(attributes.merge(name: label))
    end
  end

  def down
    DeliverableStatus.where("id <= #{DEFAULT_STATUSES.length}").destroy_all
  end
end
