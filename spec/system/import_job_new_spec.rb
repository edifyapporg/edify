require "rails_helper"

describe "Start a membership list import" do
  let(:unit) { units(:sunny_hills) }
  let(:bishopric_user) { users(:sunny_bishopric) }
  let(:individuals_paste) { file_fixture("raw_member_list_sunny_hills.txt").read }
  let(:households_paste) { file_fixture("raw_household_list.txt").read }

  # A textarea submits its line breaks as CRLF.
  def submitted(paste)
    paste.gsub("\n", "\r\n")
  end

  before { login_as bishopric_user, scope: :user }

  it "offers the tabs as three choices with none of them picked" do
    visit new_import_job_path

    expect(page).to have_field("import_job_kind_individuals", type: "radio", checked: false, visible: :all)
    expect(page).to have_field("import_job_kind_households", type: "radio", checked: false, visible: :all)
    expect(page).to have_field("import_job_kind_both", type: "radio", checked: false, visible: :all)
    expect(page).to have_css("label[for=import_job_kind_both]", text: "Individuals + Households")
    expect(page).to have_content("Import the Individuals tab first")
  end

  it "imports the Individuals tab" do
    visit new_import_job_path
    choose "import_job_kind_individuals", allow_label_click: true
    fill_in "Individuals tab", with: individuals_paste

    expect { click_button "Import" }.to change(ImportJob, :count).by(1)

    import_job = ImportJob.order(:id).last
    expect(import_job).to be_individuals
    expect(import_job.data_string).to eq(submitted(individuals_paste))
    expect(ImporterJob).to have_been_enqueued.with(import_job: import_job, next_import_job: nil)
    expect(page).to have_current_path(import_jobs_path)
  end

  it "imports the Households tab" do
    visit new_import_job_path
    choose "import_job_kind_households", allow_label_click: true
    fill_in "Households tab", with: households_paste

    expect { click_button "Import" }.to change(ImportJob, :count).by(1)

    import_job = ImportJob.order(:id).last
    expect(import_job).to be_households
    expect(import_job.data_string).to eq(submitted(households_paste))
  end

  it "imports both tabs as two jobs, queueing Individuals to run Households after it" do
    visit new_import_job_path
    choose "import_job_kind_both", allow_label_click: true
    fill_in "Individuals tab", with: individuals_paste
    fill_in "Households tab", with: households_paste

    expect { click_button "Import" }.to change(ImportJob, :count).by(2)

    individuals_job, households_job = ImportJob.order(:id).last(2)
    expect(individuals_job).to be_individuals
    expect(individuals_job.data_string).to eq(submitted(individuals_paste))
    expect(households_job).to be_households
    expect(households_job.data_string).to eq(submitted(households_paste))
    expect(households_job).to be_waiting
    expect(ImporterJob).to have_been_enqueued.exactly(:once)
    expect(ImporterJob).to have_been_enqueued.with(import_job: individuals_job, next_import_job: households_job)
  end

  it "ignores the other tab's box when only one tab is chosen" do
    visit new_import_job_path
    choose "import_job_kind_households", allow_label_click: true
    fill_in "Individuals tab", with: individuals_paste
    fill_in "Households tab", with: households_paste

    expect { click_button "Import" }.to change(ImportJob, :count).by(1)
    expect(ImportJob.order(:id).last).to be_households
  end

  it "refuses an import with no tab chosen, keeping the paste" do
    visit new_import_job_path
    fill_in "Individuals tab", with: individuals_paste

    expect { click_button "Import" }.not_to change(ImportJob, :count)

    expect(page).to have_content("Choose which tab you copied before importing.")
    expect(page).to have_field("Individuals tab", with: submitted(individuals_paste))
    expect(ImporterJob).not_to have_been_enqueued
  end

  context "with JavaScript", :js do
    it "holds Import back and shows only the boxes for the chosen tabs" do
      visit new_import_job_path

      expect(page).to have_button("Import", disabled: true)
      expect(page).to have_no_field("Individuals tab")
      expect(page).to have_no_field("Households tab")

      find("label[for=import_job_kind_households]").click
      expect(page).to have_button("Import", disabled: false)
      expect(page).to have_no_field("Individuals tab")
      expect(page).to have_field("Households tab")

      find("label[for=import_job_kind_both]").click
      expect(page).to have_field("Individuals tab")
      expect(page).to have_field("Households tab")

      find("label[for=import_job_kind_individuals]").click
      expect(page).to have_field("Individuals tab")
      expect(page).to have_no_field("Households tab")
    end
  end
end
