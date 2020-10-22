class DeliverableStatusesController < ApplicationController
  layout 'admin'
  before_filter :require_admin
  before_filter :find_deliverable_status, only: [:edit, :update, :destroy]

  def index
    @deliverable_statuses = DeliverableStatus.sorted
  end

  def new
    @deliverable_status = DeliverableStatus.new
  end

  def edit
  end

  def update
    if @deliverable_status.update_attributes(deliverable_status_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to deliverable_statuses_path
    else
      render action: 'edit'
    end
  end

  def create
    @deliverable_status = DeliverableStatus.new(deliverable_status_params)

    if @deliverable_status.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to deliverable_statuses_path
    else
      render action: 'new'
    end
  end

  def destroy
    @deliverable_status.destroy

    redirect_to deliverable_statuses_path
  end

  private

  def deliverable_status_params
    if defined?(ActionController::Parameters)
      params.require(:deliverable_status).permit!
    else
      params[:deliverable_status]
    end
  end

  def find_deliverable_status
    @deliverable_status = DeliverableStatus.find(params[:id])
  end
end
