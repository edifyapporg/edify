require "edify/etl"

class ImporterJob < ::ApplicationJob
  queue_as :default

  NOT_RUN_MESSAGE = "Not run: the Individuals import it depends on did not finish. " \
                    "Fix the Individuals paste and import both tabs again.".freeze

  # A next_import_job runs only once this one has finished cleanly: Households link to members by name, so running them
  # after a failed Individuals import would link almost nothing.
  def perform(import_job:, next_import_job: nil)
    ::Edify::Etl::ImportManager.perform!(import_job)
  ensure
    run_or_skip(import_job, next_import_job) if next_import_job
  end

  private

  def run_or_skip(import_job, next_import_job)
    if import_job.reload.finished?
      ::Edify::Etl::ImportManager.perform!(next_import_job)
    else
      next_import_job.update(status: :failed, error_message: [NOT_RUN_MESSAGE].to_json)
    end
  end
end
