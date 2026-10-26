require "rails_helper"

RSpec.describe ImporterJob, type: :job do
  subject { described_class.new }

  let(:import_job) { import_jobs(:import_job_7) }

  it "enqueues the job" do
    expect { described_class.perform_later(import_job: import_job) }.to have_enqueued_job(described_class)
  end

  describe "#perform" do
    let(:perform_job) { subject.perform(import_job: import_job) }

    before { allow(::Edify::Etl::ImportManager).to receive(:perform!) }

    it "sends a message to Edify::Etl::ImportManager for each unit" do
      expect(::Edify::Etl::ImportManager).to receive(:perform!).with(import_job)
      perform_job
    end

    context "when another import is to follow" do
      let(:individuals_job) { ImportJob.create!(unit: units(:sunny_hills), kind: :individuals, status: :waiting) }
      let(:households_job) { ImportJob.create!(unit: units(:sunny_hills), kind: :households, status: :waiting) }
      let(:perform_job) { subject.perform(import_job: individuals_job, next_import_job: households_job) }

      it "runs the next import once the first has finished" do
        allow(::Edify::Etl::ImportManager).to receive(:perform!).with(individuals_job) do
          individuals_job.update!(status: :finished)
        end

        perform_job

        expect(::Edify::Etl::ImportManager).to have_received(:perform!).with(individuals_job).ordered
        expect(::Edify::Etl::ImportManager).to have_received(:perform!).with(households_job).ordered
      end

      it "fails the next import without running it when the first fails" do
        allow(::Edify::Etl::ImportManager).to receive(:perform!).with(individuals_job) do
          individuals_job.update!(status: :failed)
        end

        perform_job

        expect(::Edify::Etl::ImportManager).not_to have_received(:perform!).with(households_job)
        expect(households_job.reload).to be_failed
        expect(households_job.parsed_errors).to eq([described_class::NOT_RUN_MESSAGE])
      end

      it "fails the next import without running it when the first raises" do
        allow(::Edify::Etl::ImportManager).to receive(:perform!).with(individuals_job).and_raise(StandardError, "boom")

        expect { perform_job }.to raise_error(StandardError, "boom")

        expect(::Edify::Etl::ImportManager).not_to have_received(:perform!).with(households_job)
        expect(households_job.reload).to be_failed
      end
    end
  end
end
