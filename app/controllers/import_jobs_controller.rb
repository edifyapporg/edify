class ImportJobsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_user
  before_action :set_import_job, only: %i[show destroy]
  after_action :verify_authorized

  KINDS = %w[individuals households both].freeze

  # GET /import_jobs
  def index
    @import_jobs = current_unit.import_jobs.includes(:owner)
  end

  # GET /import_jobs/:id
  def show
  end

  # GET /import_jobs/new
  def new
  end

  # POST /import_jobs
  #
  # Importing both tabs makes one job per tab. Only the Individuals job is queued; it runs the Households job once the
  # members exist for the households to link to.
  def create
    @kind = import_job_params[:kind]
    @individuals_data = import_job_params[:individuals_data]
    @households_data = import_job_params[:households_data]

    unless @kind.in?(KINDS)
      flash.now[:danger] = t("controllers.import_jobs_controller.kind_missing")
      return render "new", status: :unprocessable_content
    end

    import_jobs = kinds_to_import.map { |kind| build_import_job(kind) }

    if save_all(import_jobs)
      ::ImporterJob.perform_later(import_job: import_jobs.first, next_import_job: import_jobs.second)
      redirect_to import_jobs_path
    else
      messages = import_jobs.flat_map { |import_job| import_job.errors.full_messages }
      flash.now[:danger] = "Unable to create import job: #{messages.join(', ')}"
      render "new", status: :unprocessable_content
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
    params.expect(import_job: %i[kind individuals_data households_data])
  end

  def kinds_to_import
    @kind == "both" ? %w[individuals households] : [@kind]
  end

  def build_import_job(kind)
    current_unit.import_jobs.new(kind: kind,
                                 data_string: import_job_params[:"#{kind}_data"].to_s,
                                 owner: current_user,
                                 status: :waiting)
  end

  def save_all(import_jobs)
    ImportJob.transaction do
      import_jobs.all?(&:save) || raise(ActiveRecord::Rollback)
    end
  end

  def set_import_job
    @import_job = current_unit.import_jobs.find(params.expect(:id))
  end
end
