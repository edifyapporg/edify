class ImportJobsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_user
  before_action :set_import_job, only: %i[show destroy]
  after_action :verify_authorized

  # GET /import_jobs
  def index
    @import_jobs = current_unit.import_jobs.includes(:owner)
  end

  # GET /import_jobs/:id
  def show
  end

  # GET /import_jobs/new
  def new
    @import_job = current_unit.import_jobs.new
  end

  # POST /import_jobs
  def create
    @import_job = current_unit.import_jobs.new(import_job_params)
    @import_job.owner = current_user
    @import_job.status = :waiting

    if @import_job.save
      ::ImporterJob.perform_later(import_job: @import_job)
      redirect_to import_jobs_path
    else
      flash.now[:danger] = "Unable to create import job: #{@import_job.errors.full_messages.join(', ')}"
      render "new"
    end
  end

  # DELETE /import_jobs/:id
  def destroy
    unless @import_job.destroy
      flash[:danger] = "Unable to delete import job: #{@import_job.errors.full_messages.join(', ')}"
    end

    redirect_to import_jobs_path(user_id: @user.id)
  end

  private

  def import_job_params
    params.expect(import_job: %i[data_string kind])
  end

  def set_import_job
    @import_job = current_unit.import_jobs.find(params[:id])
  end
end
