require "rails_helper"

RSpec.describe ::StaleSpeakerSerializer do
  it "gives name, gender, age group and last talk date only" do
    member = ::Member.new(name: "Doe, Jane", gender: :female, birthdate: 15.years.ago.to_date,
                          email: "jane@example.com", phone_number: "303-555-0100")
    allow(member).to receive(:last_talk_date).and_return(Date.new(2025, 3, 2))

    expect(described_class.call(member))
      .to eq(name: "Doe, Jane", gender: "female", group: "youth", last_talk_date: Date.new(2025, 3, 2))
  end
end
