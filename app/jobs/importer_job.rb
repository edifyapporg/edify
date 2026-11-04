require "edify/etl"

class ImporterJob < ::ApplicationJob
  queue_as :default

  NOT_RUN_MESSAGE = "Not run: the Individuals import it depends on saved no members. " \
                    "Fix the Individuals paste and import both tabs again.".freeze

  # A next import runs once this one has saved anyone: Households link to members by name, so running them after an
  # Individuals import that saved nobody would link almost nothing. A few rows failing validation is no reason to hold
  # Households back; anyone it cannot match stays unlinked until a later import.
  #
  # The next import is passed by id so that deleting its waiting row skips it, rather than discarding this job too.
  def perform(import_job:, next_import_job_id: nil)
    ::Edify::Etl::ImportManager.perform!(import_job)
  ensure
    next_import_job = ::ImportJob.find_by(id: next_import_job_id) if next_import_job_id
    run_or_skip(import_job, next_import_job) if next_import_job
  end

  private

  def run_or_skip(import_job, next_import_job)
    if import_job.reload.succeeded_count.positive?
      ::Edify::Etl::ImportManager.perform!(next_import_job)
    else
      next_import_job.update(status: :failed, error_message: [NOT_RUN_MESSAGE].to_json)
    end
  end
end
