# Redmine Budget
# Copyright (C) 2016  Omega Code
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require_dependency 'redmine_budget'

Redmine::Plugin.register :redmine_budget do
  name 'Redmine Budget'
  author "Ralph Gutkowski"
  description "Manage project budget and measure performance using deliverables"
  author_url 'http://github.com/rgtk'
  version '0.11.1'

  requires_redmine version_or_higher: '2.3.0'

  settings default: {
    'supervisor_group_id' => '',
    'list_default_columns' => %w(status subject budget labor_budget spent materials overhead
                                 profit progress),
    'application_menu' => true,
    'top_menu' => false,
  }, partial: 'settings/redmine_budget'

  project_module :budget do
    permission :view_budget, { deliverables: [:index, :issues] }
    permission :manage_budget, { deliverables: [:new, :edit, :create, :update,
                                                :destroy, :preview, :bulk_assign_issues] }
    permission :set_deliverable, {}
  end

  menu :application_menu, :budget,
       { controller: 'deliverables', action: 'index' },
       caption: :label_budget,
       if: Proc.new { RedmineBudget::Settings.application_menu? \
                      && User.current.allowed_to?(:view_budget, nil, global: true) }

  menu :top_menu, :budget,
       { controller: 'deliverables', action: 'index' },
       caption: :label_budget,
       if: Proc.new { RedmineBudget::Settings.top_menu? \
                      && User.current.allowed_to?(:view_budget, nil, global: true) }

  menu :project_menu, :budget,
       { controller: 'deliverables', action: 'index'},
       caption: :label_budget, after: :activity, param: :project_id

  menu :admin_menu, :budget,
       { controller: 'deliverable_statuses', action: 'index'},
       caption: :label_deliverable_status_plural, after: :enumerations
end

RedmineBudget.install
