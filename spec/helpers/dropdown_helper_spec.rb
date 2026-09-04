require "rails_helper"

RSpec.describe DropdownHelper, type: :helper do
  describe "#filter_members_age_dropdown" do
    subject(:dropdown) { helper.filter_members_age_dropdown(params) }

    let(:params) { ActionController::Parameters.new(controller: "members", action: "index").permit! }
    let(:youth_threshold) { (Member::YOUTH_AGE - 1).years.ago.beginning_of_year.to_date.to_s }
    let(:adult_threshold) { (Member::ADULT_AGE - 1).years.ago.beginning_of_year.to_date.to_s }

    it "offers each group a speaker can belong to" do
      expect(dropdown).to include("All", "Adults", "Youth", "Children")
    end

    it "bounds youth below so children are a group of their own" do
      expect(dropdown).to include("q%5Bbirthdate_gteq%5D=#{adult_threshold}")
      expect(dropdown).to include("q%5Bbirthdate_lt%5D=#{youth_threshold}")
    end

    context "when the children filter is active" do
      let(:params) do
        ActionController::Parameters.new(controller: "members", action: "index",
                                         q: { birthdate_gteq: youth_threshold }).permit!
      end

      it "names the active filter" do
        expect(dropdown).to include("Children")
        expect(dropdown).to match(/dropdown-item[^>]*active/)
      end
    end
  end
end
