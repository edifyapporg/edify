require "edify/etl"

class ImporterJob < ::ApplicationJob
  queue_as :default

  NOT_RUN_MESSAGE = "Not run: the Individuals import it depends on saved no members. " \
                    "Fix the Individuals paste and import both tabs again.".freeze
  CRASHED_MESSAGE = "Not run: the Individuals import it depends on stopped with an error. " \
                    "Import both tabs again.".freeze

  # A next import runs once this one has saved anyone: Households link to members by name, so running them after an
  # Individuals import that saved nobody would link almost nothing. A few rows failing validation is no reason to hold
  # Households back; anyone it cannot match stays unlinked until a later import.
  #
  # If this import raises, the next one is skipped even if some rows were saved, and the original error is re-raised so
  # it reaches error tracking rather than being replaced by one from the next import.
  #
  # The next import is passed by id so that deleting its waiting row skips it, rather than discarding this job too.
  def perform(import_job:, next_import_job_id: nil)
    begin
      ::Edify::Etl::ImportManager.perform!(import_job)
    rescue StandardError
      skip_next(next_import_job_id, CRASHED_MESSAGE)
      raise
    end

    run_or_skip(import_job, next_import_job_id) if next_import_job_id
  end

  private

  def run_or_skip(import_job, next_import_job_id)
    if import_job.reload.succeeded_count.positive?
      next_import_job = ::ImportJob.find_by(id: next_import_job_id)
      ::Edify::Etl::ImportManager.perform!(next_import_job) if next_import_job
    else
      skip_next(next_import_job_id, NOT_RUN_MESSAGE)
    end
  end

  def skip_next(next_import_job_id, message)
    return unless next_import_job_id

    ::ImportJob.find_by(id: next_import_job_id)&.update(status: :failed, error_message: [message].to_json)
  end
end
