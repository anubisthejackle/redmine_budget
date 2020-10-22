class DeliverableQueriesController < ApplicationController
  menu_item :deliverables
  before_filter :find_query, :except => [:new, :create, :index]
  before_filter :find_optional_project, :only => [:new, :create]

  accept_api_auth :index

  include QueriesHelper

  def index
    case params[:format]
    when 'xml', 'json'
      @offset, @limit = api_offset_and_limit
    else
      @limit = per_page_option
    end
    @query_count = DeliverableQuery.visible.count
    @query_pages = Paginator.new @query_count, @limit, params['page']
    @queries = DeliverableQuery.visible.
                    order("#{Query.table_name}.name").
                    limit(@limit).
                    offset(@offset).
                    to_a
    respond_to do |format|
      format.html {render_error :status => 406}
      format.api
    end
  end

  def new
    @query = DeliverableQuery.new
    @query.user = User.current
    @query.project = @project
    @query.build_from_params(params)
  end

  def create
    @query = DeliverableQuery.new
    @query.user = User.current
    @query.project = @project
    update_query_from_params

    if @query.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to_deliverables(:query_id => @query)
    else
      render :action => 'new', :layout => !request.xhr?
    end
  end

  def edit
  end

  def update
    update_query_from_params

    if @query.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to_deliverables(:query_id => @query)
    else
      render :action => 'edit'
    end
  end

  def destroy
    @query.destroy
    redirect_to_deliverables(:set_filter => 1)
  end

  private

  def find_query
    @query = DeliverableQuery.find(params[:id])
    @project = @query.project
    render_403 unless @query.editable_by?(User.current)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_optional_project
    @project = Project.find(params[:project_id]) if params[:project_id]
    render_403 unless User.current.allowed_to?(:manage_budget, @project, :global => true)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def update_query_from_params
    @query.project = params[:query_is_for_all] ? nil : @project
    @query.build_from_params(params)
    @query.column_names = nil if params[:default_columns]
    @query.sort_criteria = params[:query] && params[:query][:sort_criteria]
    @query.name = params[:query] && params[:query][:name]

    if defined?(DeliverableQuery::VISIBILITY_PRIVATE) and @query.respond_to?(:roles)
      if User.current.allowed_to?(:manage_public_queries, @query.project) || User.current.admin?
        @query.visibility = (params[:query] && params[:query][:visibility]) || DeliverableQuery::VISIBILITY_PRIVATE
        @query.role_ids = params[:query] && params[:query][:role_ids]
      else
        @query.visibility = DeliverableQuery::VISIBILITY_PRIVATE
      end
    end
    @query
  end

  def redirect_to_deliverables(options)
    if @project
      redirect_to project_deliverables_path(@project)
    else
      redirect_to deliverables_path
    end
  end
end
