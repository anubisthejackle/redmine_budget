class DeliverablesController < ApplicationController
  include RedmineBudget
  include SortHelper
  include DeliverableQueriesHelper

  before_filter :check_default_status, only: [:new, :create]
  before_filter :permit_params
  before_filter :find_optional_project, only: [:index, :new, :create, :issues]
  before_filter :find_deliverable, only: [:show, :context_menu, :edit, :update, :destroy]
  before_filter :retrieve_query, only: [:index]

  helper :queries
  helper :sort
  helper :custom_fields
  helper :deliverable_queries
  helper :context_menus
  helper :attachments

  menu_item :budget

  def index
    sort_update(@query.sortable_columns)

    @query.sort_criteria = sort_criteria.to_a

    @budget = Budget.new(@project.id) if @project

    if @query.valid?
      case params[:format]
      when 'csv', 'pdf'
        @limit = Setting.issues_export_limit.to_i
      when 'atom'
        @limit = Setting.feeds_limit.to_i
      when 'xml', 'json'
        @offset, @limit = api_offset_and_limit
      else
        @limit = per_page_option
      end

      @deliverable_count = @query.deliverable_count
      @deliverable_pages = Paginator.new(@deliverable_count, @limit, params[:page])
      @offset ||= @deliverable_pages.offset

      @deliverables = @query.deliverables(order: sort_clause,
                                          offset: @offset,
                                          limit: @limit,
                                          cache: true)

      respond_to do |format|
        format.html { render :layout => !request.xhr? }
        format.csv  { send_data(query_to_csv(@deliverables, @query, params),
                                :type => 'text/csv; header=present', :filename => 'deliverables.csv') }
      end
    else
      respond_to do |format|
        format.html { render :layout => !request.xhr? }
        format.csv { render :nothing => true }
      end
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def show
  end

  def new
    if params[:copy_from]
      @copy_from = Deliverable.find(params[:copy_from])
      return render_403 unless @copy_from.visible?
      @deliverable = @copy_from.copy
      @project = @deliverable.project
    else
      @deliverable = HourlyDeliverable.new
    end
  end

  # Saves a new Deliverable
  def create
    if params[:deliverable][:type] == FixedDeliverable.name
      @deliverable = FixedDeliverable.new(deliverable_params)
    elsif params[:deliverable][:type] == HourlyDeliverable.name
      @deliverable = HourlyDeliverable.new(deliverable_params)
    else
      @deliverable = Deliverable.new(deliverable_params)
    end

    @deliverable.project = @project

    @deliverable.save_attachments(params[:attachments])

    if @deliverable.save
      render_attachment_warning_if_needed(@deliverable)
      flash[:notice] = l(:notice_successful_create)

      redirect_to deliverable_path(@deliverable)
    else
      render :new
    end
  end

  def edit
  end

  def update
    if deliverable_params[:type] != @deliverable.class.name
      @deliverable = @deliverable.change_type(deliverable_params[:type])
    end

    if @deliverable.protected? and not supervisor?
      deliverable_params.delete_if { |k, v| @deliverable.protected_fields.include?(k) }

      if @deliverable.protected_fields.include?('budget')
        deliverable_params.delete_if { |k, v| Deliverable::BUDGET_ATTRIBUTES.include?(k) }
      end
    end

    @deliverable.save_attachments(params[:attachments])

    if @deliverable.update_attributes(deliverable_params)
      render_attachment_warning_if_needed(@deliverable)
      flash[:notice] = l(:notice_successful_update)

      redirect_to deliverable_path(@deliverable)
    else
      render :edit
    end
  end

  def destroy
    @deliverables.each do |deliverable|
      deliverable.destroy if deliverable.editable?
    end

    flash[:notice] = l(:notice_successful_delete)

    respond_to do |format|
      format.html {
        if @projects and @projects.length == 1
          redirect_to project_deliverables_path(@projects.first.identifier)
        else
          redirect_to deliverables_path
        end
      }
      format.api {
        render_api_ok
      }
    end
  end

  def context_menu
    render layout: false
  end

  def update_form
    @deliverable = Deliverable.new(deliverable_params.except(:id, :type, :assigns_attributes))
  end

  # Create a query in the session and redirects to the issue list with that query
  def issues
    @deliverable = Deliverable.find(params[:deliverable_id])
    @project = @deliverable.project
    @query = IssueQuery.new(:name => "_")
    @query.project = @project
    @query.add_filter("status_id", '*')
    @query.add_filter("cf_#{RedmineBudget.custom_field.id}", '=',[params[:deliverable_id]])

    session[:query] = {:project_id => @query.project_id, :filters => @query.filters}

    redirect_to :controller => 'issues', :action => 'index',
                :project_id => @project.identifier
  end

  # Assigns issues to the Deliverable based on their Version
  def assign_issues
    @deliverable = Deliverable.find(params[:deliverable_id])

    render_404 and return unless @deliverable
    render_403 and return unless @deliverable.editable?

    number_updated = @deliverable.assign_issues_by_version(params[:version_id])

    flash[:notice] = l(:message_updated_issues, number_updated)

    render nothing: true
  end

  def auto_complete
    q = (params[:q] || params[:term]).to_s.strip

    if q.present?
      if params[:project_id]
        scope = Deliverable.where(project_id: params[:project_id])
      else
        scope = Deliverable
      end

      scope = scope.where(Deliverable.arel_table[:subject].lower.matches("#{q.downcase}%"))
      scope = scope.order(Deliverable.arel_table[:id].desc)

      render json: scope.all.map { |d| { id: d.id, label: d.subject, value: d.id } }
    end
  end

  def calculator
    type = params[:deliverable][:type]

    return render_403 unless Deliverable::TYPES.include?(type)

    klass = type.constantize
    @deliverable = klass.new(params[:deliverable].except(:type))

    render partial: 'calculator'
  end

  private

  def check_default_status
    if DeliverableStatus.default.nil?
      render_error l(:error_no_default_issue_status)

      false
    end
  end

  def supervisor?
    User.current.is_or_belongs_to?(Settings.supervisor_group) \
    or User.current.admin?
  end

  def find_deliverable
    if params.key?(:id)
      @deliverable = Deliverable.readonly(false).visible.find(params[:id])
      @deliverables = [@deliverable]
      @project = @deliverable.project
    elsif params.key?(:ids)
      @deliverables = Deliverable.visible.find(params[:ids])
      @deliverable = @deliverables.first if @deliverables.length == 1
      @projects = @deliverables.map(&:project).uniq

      render_403 if @deliverables.empty?
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def permit_params
    params.permit! if defined?(ActionController::Parameters)
  end

  def deliverable_params
    params[:deliverable]
  end

  def retrieve_query
    if params[:query_id]
      cond = "project_id IS NULL"
      cond << " OR project_id = #{@project.id}" if @project

      @query = DeliverableQuery.where(cond).find_by_id(params[:query_id])

      session[:budget_query] = { id: @query.id } if @query

      sort_clear
    elsif session[:budget_query] and params[:set_filter].nil?
      q = session[:budget_query]

      if q[:id]
        @query = DeliverableQuery.find_by_id(q[:id])
      elsif q[:project_id].nil? && @project.nil? or q[:project_id] == @project.try(:id)
        @query = DeliverableQuery.new(name: '_',
                                      filters: q[:filters],
                                      group_by: q[:group_by],
                                      column_names: q[:column_names])
      end
    end

    if @query.nil?
      @query = DeliverableQuery.new(name: '_')

      query_params = params.dup
      query_params['c'] ||= Settings.list_default_columns

      @query.build_from_params(query_params)
    end

    if api_request? || params[:set_filter]
      session[:budget_query] = {
        filters: @query.filters,
        group_by: @query.group_by,
        column_names: @query.column_names
      }

      session[:budget_query][:project_id] = @project.id if @project
    end

    if @query.persisted? and not @query.visible?
      raise ::Unauthorized
    end

    # group by project by default in global view
    @query.group_by = 'project' if @project.nil?

    if @project
      @query.project = @project
      @query.add_filter('project_id', '=', [@project.id.to_s])
    end

    if params[:f].nil? and !@query.has_filter?('status_id')
      @query.add_filter('status_id', 'o', [''])
    end
  end

  # Sorting orders
  def sort_order
    if session[@sort_name] && %w(score spent progress labor_budget).include?(session[@sort_name][:key])
      return {}
    else
      return { :order => sort_clause }
    end
  end

  # Sort +deliverables+ manually using the virtual fields
  def sort_if_needed(deliverables)
    if session[@sort_name] && %w(score spent progress labor_budget).include?(session[@sort_name][:key])
      case session[@sort_name][:key]
      when "score" then
          sorted = deliverables.sort {|a,b| a.score <=> b.score}
      when "spent" then
          sorted = deliverables.sort {|a,b| a.spent <=> b.spent}
      when "progress" then
          sorted = deliverables.sort {|a,b| a.progress <=> b.progress}
      when "labor_budget" then
          sorted = deliverables.sort {|a,b| a.labor_budget <=> b.labor_budget}
      end

      return sorted if session[@sort_name][:order] == 'asc'
      return sorted.reverse! if session[@sort_name][:order] == 'desc'
    else
      return deliverables
    end
  end
end
