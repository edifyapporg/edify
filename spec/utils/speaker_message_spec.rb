require "rails_helper"

describe SpeakerMessage do
  let(:member) { members(:hill_waylon) }
  let(:sender) { users(:sunny_bishopric) }
  let(:talk) { talks(:talk_2) }
  let(:unit) { units(:sunny_hills) }

  describe ".for_talk" do
    subject(:message) { described_class.for_talk(talk, template: :invitation, sender: sender) }

    it "greets the speaker by first name" do
      expect(message.email_body).to start_with("Dear Waylon,")
    end

    it "invites the speaker to the meeting on its date" do
      expect(message.email_body)
        .to include("The Bishopric would like to invite you to speak in sacrament meeting on Sunday, April 10.")
    end

    it "gives the length of the talk and the assigned topic" do
      expect(message.email_body)
        .to include("approximately 8 to 10 minutes in length, or about 8 minutes if there are three speakers")
    end

    it "leaves out the assignment when the talk has no purpose" do
      expect(message.email_body).not_to include("Assignment:")
    end

    context "when the talk has a purpose" do
      let(:talk) { talks(:talk_1) }

      it "names the assignment" do
        expect(message.email_body).to include("Assignment: Departing Missionary.")
      end
    end

    it "tells the speaker what to focus on and what to avoid" do
      expect(message.email_body).to include("Please focus on:", "* Keeping your message centered on Jesus Christ.")
      expect(message.email_body).to include("Please also keep in mind:", "* Avoid political or divisive topics.")
    end

    it "names the time the meeting must conclude by" do
      expect(message.email_body).to include("so the meeting concludes by 9:55 am, or before")
    end

    it "signs the message from the bishopric" do
      expect(message.email_body).to end_with("Sincerely,\nThe Bishopric")
    end

    it "greets the speaker by surname in the text message and introduces the sender" do
      expect(message.sms_body).to start_with("Hi Brother Hill, this is Brother User from the bishopric.")
    end

    it "asks about the date and the length in the text message" do
      expect(message.sms_body)
        .to include("You would speak for 8 to 10 minutes.",
                    "Are you in town and available to speak that day?")
    end

    context "when the speaker is a youth" do
      let(:member) { Member.new(name: "Wilderman, Kati", gender: :female, birthdate: 15.years.ago.to_date) }
      let(:message) do
        described_class.new(template: :invitation, member: member, speaker_name: member.name, sender: sender,
                            meeting_date: talk.date, topic: talk.topic)
      end

      it "asks for a shorter talk and speaks to them by first name" do
        expect(message.sms_body).to start_with("Hi Kati,")
        expect(message.sms_body).to include("The talk would be about 3 to 5 minutes.")
        expect(message.email_body).to include("approximately 3 to 5 minutes in length")
      end
    end

    context "when the speaker has no birthdate on record" do
      let(:member) { Member.new(name: "Wilderman, Kati", gender: :female, birthdate: nil) }
      let(:message) do
        described_class.new(template: :invitation, member: member, speaker_name: member.name, sender: sender,
                            meeting_date: talk.date, topic: talk.topic)
      end

      it "assumes an adult rather than raising on the missing age" do
        expect { message.sms_body }.not_to raise_error
        expect(message.sms_body).to include("You would speak for 8 to 10 minutes.")
      end
    end

    context "when the wording contains a literal percent sign" do
      before do
        # The locale files interpolate with %{...}, so that is what a segment under test has to use.
        greeting = "Give 100% effort, %{first_name}." # rubocop:disable Style/FormatStringToken

        I18n.backend.store_translations(:en, speaker_messages: { invitation: { adult: { email: { greeting: greeting } } } })
      end

      after { I18n.backend.reload! }

      it "renders it instead of raising" do
        expect(message.email_body).to start_with("Give 100% effort, Waylon.")
      end
    end

    context "when the speaker is not matched to a member" do
      let(:talk) { talks(:talk_3) }

      it "has no way to reach the speaker" do
        expect(message).not_to be_available
        expect(message.sms_url).to be_nil
        expect(message.mailto_url).to be_nil
      end
    end

    context "when there is no sender" do
      subject(:message) { described_class.for_talk(talk, template: :invitation) }

      it "falls back to introducing an unnamed member of the bishopric" do
        expect(message.sms_body).to start_with("Hi Brother Hill, this is a member of the bishopric.")
      end
    end
  end

  describe ".for_member" do
    subject(:message) { described_class.for_member(member, template: :invitation, sender: sender) }

    it "falls back to an invitation that names no meeting date" do
      expect(message.email_body).to start_with("Dear Waylon,")
      expect(message.email_body)
        .to include("The Bishopric would like to invite you to speak in sacrament meeting. We look forward")
      expect(message.email_body).not_to include("sacrament meeting on")
    end

    it "falls back to giving the length without a topic" do
      expect(message.email_body).to include("approximately 8 to 10 minutes in length, or about 8 minutes if there are three speakers.")
      expect(message.email_body).not_to include("your assigned topic is")
    end

    it "falls back to a text message that asks about no particular day" do
      expect(message.sms_body).to include("Are you available to speak?")
      expect(message.sms_body).not_to include("Sacrament Meeting on")
    end

    context "when a meeting date is given" do
      subject(:message) do
        described_class.for_member(member, template: :invitation, meeting_date: Date.new(2022, 5, 15), sender: sender)
      end

      it "uses the dated invitation instead of the fallback" do
        expect(message.email_body).to include("speak in sacrament meeting on Sunday, May 15.")
        expect(message.email_body.scan("would like to invite you to speak").length).to eq(1)
      end

      it "uses the dated text message instead of the fallback" do
        expect(message.sms_body).to include("Sacrament Meeting on Sunday, May 15.")
        expect(message.sms_body).not_to include("Are you available to speak?")
      end
    end
  end

  describe "#label" do
    it "returns the name of the template" do
      expect(described_class.for_member(member, template: :guidance).label).to eq("Preparation guidance")
      expect(described_class.label(:reminder)).to eq("Reminder")
    end
  end

  describe "#spoken_name" do
    it "reverses the roster's sort order" do
      expect(described_class.for_talk(talk, template: :invitation).spoken_name).to eq("Waylon Hill")
    end

    it "handles a name entered without a comma" do
      message = described_class.new(template: :invitation, speaker_name: "Gordon Ghibli")

      expect(message.spoken_name).to eq("Gordon Ghibli")
    end

    it "is nil without a speaker" do
      expect(described_class.new(template: :invitation).spoken_name).to be_nil
    end
  end

  describe "#mailto_url" do
    subject(:url) { described_class.for_talk(talk, template: :reminder, sender: sender).mailto_url }

    it "addresses the member and pre-fills the subject and body" do
      expect(url).to start_with("mailto:jorge.yost@oreilly.info?subject=")
      expect(url).to include(ERB::Util.url_encode("Reminder: your talk in Sacrament Meeting"))
      expect(url).to include("&body=#{ERB::Util.url_encode('Dear Waylon,')}")
    end

    context "when the member has no email" do
      before { member.update_column(:email, nil) }

      it { expect(url).to be_nil }
    end
  end

  describe "#sms_url" do
    subject(:url) { described_class.for_talk(talk, template: :reminder, sender: sender).sms_url }

    it "strips the phone number to digits and pre-fills the body" do
      expect(url).to start_with("sms:6019156744?&body=")
      expect(url).to include(ERB::Util.url_encode("Hi Brother Hill"))
    end

    it "keeps an international prefix" do
      member.update_column(:phone_number, "+1 (601) 915-6744")

      expect(url).to start_with("sms:+16019156744?&body=")
    end

    context "when the member has no phone number" do
      before { member.update_column(:phone_number, nil) }

      it { expect(url).to be_nil }
    end
  end

  describe "sms bodies" do
    subject(:message) { described_class.for_talk(talk, template: :guidance, sender: sender) }

    it "is shorter than the email body and uses single line breaks" do
      expect(message.sms_body.length).to be < message.email_body.length
      expect(message.sms_body).not_to include("\n\n")
    end
  end

  describe "templates" do
    it "builds a body for every template and medium" do
      described_class::TEMPLATES.each do |template|
        message = described_class.for_talk(talk, template: template, sender: sender)

        expect(message.subject).to be_present
        expect(message.email_body).to be_present
        expect(message.sms_body).to be_present
      end
    end

    it "rejects an unknown template" do
      expect { described_class.for_talk(talk, template: :thank_you) }
        .to raise_error(ArgumentError, "Unknown template: thank_you")
    end
  end

  describe "speaker names without a comma" do
    subject(:message) do
      described_class.new(template: :invitation, speaker_name: "Gordon Ghibli", unit: unit)
    end

    it "uses the first word as the first name" do
      expect(message.email_body).to start_with("Dear Gordon,")
    end
  end

  describe "the group a speaker is written to as" do
    let(:household) { unit.households.create!(name: "Hill, Waylon & Wanda") }

    def message_for(member, template: :invitation)
      described_class.for_member(member, template: template, meeting_date: Date.new(2022, 4, 10), sender: sender)
    end

    def member_aged(years, name: "Hill, Junior")
      unit.members.create!(name: name, gender: :male, birthdate: years.years.ago.to_date)
    end

    it "asks a child for the shortest talk and writes to the family" do
      message = message_for(member_aged(9))

      expect(message.email_body).to start_with("Dear Brother Hill,")
      expect(message.email_body).to include("about 30 seconds to 2 minutes long")
      expect(message.sms_body).to include("It would be a short talk, about 30 seconds to 2 minutes.")
    end

    it "asks a youth for a shorter talk than an adult" do
      message = message_for(member_aged(15))

      expect(message.email_body).to include("approximately 3 to 5 minutes in length")
      expect(message.email_body).not_to include("if there are three speakers")
    end

    it "tells an adult the length depends on how many speakers there are" do
      message = message_for(member_aged(40))

      expect(message.email_body).to include("approximately 8 to 10 minutes in length, or about 8 minutes if there " \
                                            "are three speakers")
    end

    it "treats a speaker with no birthdate as an adult" do
      message = described_class.new(template: :invitation, speaker_name: "Hill, Waylon", sender: sender)

      expect(message.email_body).to include("approximately 8 to 10 minutes in length")
    end

    describe "inviting a child alongside their parents" do
      let(:child) { member_aged(9) }
      let(:parent) { unit.members.create!(name: "Hill, Waylon", gender: :male, birthdate: 40.years.ago.to_date) }

      before do
        child.update!(phone_number: "801-555-0101")
        parent.update!(phone_number: "(801) 555-0202")
        household.household_members.create!(name: parent.name, member: parent, position: 0, parent: true)
        household.household_members.create!(name: child.name, member: child, position: 1, listed_age: 9)
      end

      it "texts the child and the parent together" do
        # The parents are the ones being asked, so they lead: a device that cannot open a group message falls back
        # to the first number.
        expect(message_for(child).sms_numbers).to eq(%w[8015550202 8015550101])
        expect(message_for(child).sms_url).to start_with("sms:8015550202,8015550101?&body=")
      end

      it "does not add parents to an adult's text" do
        adult = member_aged(40, name: "Hill, Grandpa")
        adult.update!(phone_number: "801-555-0303")
        household.household_members.create!(name: adult.name, member: adult, position: 2)

        expect(message_for(adult).sms_numbers).to eq(["8015550303"])
      end

      it "still reaches the parents when the child has no phone of their own" do
        child.update!(phone_number: nil)

        expect(message_for(child).sms_numbers).to eq(["8015550202"])
        expect(message_for(child)).to be_sms_available
      end
    end
  end

  describe "who a message is addressed to" do
    let(:unit) { units(:sunny_hills) }
    let(:household) { unit.households.create!(name: "Ngarupe, Davis & Kim") }
    let(:father) do
      unit.members.create!(name: "Ngarupe, Davis", gender: :male, birthdate: 40.years.ago.to_date,
                           phone_number: "801-555-0201", email: "davis@example.com")
    end
    let(:mother) do
      unit.members.create!(name: "Ngarupe, Kim", gender: :female, birthdate: 39.years.ago.to_date,
                           phone_number: "801-555-0202", email: "kim@example.com")
    end

    def add_parent(person, position)
      household.household_members.create!(name: person.name, member: person, position: position, parent: true)
    end

    def speaker_aged(years, **attributes)
      member = unit.members.create!(name: "Ngarupe, Junior", gender: :male, birthdate: years.years.ago.to_date,
                                    **attributes)
      household.household_members.create!(name: member.name, member: member, position: 9, listed_age: years)
      member
    end

    def invitation_for(member)
      described_class.for_member(member, template: :invitation, meeting_date: Date.new(2022, 4, 10), sender: sender)
    end

    context "when a child has both parents" do
      before do
        add_parent(father, 0)
        add_parent(mother, 1)
      end

      it "addresses them together" do
        message = invitation_for(speaker_aged(9))

        expect(message.email_body).to start_with("Dear Brother and Sister Ngarupe,")
        expect(message.sms_body).to start_with("Hi Brother and Sister Ngarupe,")
      end

      it "puts both parents on the message, and the child too when they have a phone" do
        child = speaker_aged(9, phone_number: "801-555-0203", email: "junior@example.com")
        message = invitation_for(child)

        expect(message.sms_numbers).to eq(%w[8015550201 8015550202 8015550203])
        expect(message.email_recipients).to eq(%w[davis@example.com kim@example.com junior@example.com])
        expect(message.email_copied).to be_empty
      end

      it "leaves the child off the thread when they have no phone" do
        expect(invitation_for(speaker_aged(9)).sms_numbers).to eq(%w[8015550201 8015550202])
      end
    end

    context "when a child has one parent" do
      before { add_parent(mother, 0) }

      it "addresses that parent alone" do
        message = invitation_for(speaker_aged(9))

        expect(message.email_body).to start_with("Dear Sister Ngarupe,")
        expect(message.sms_body).to start_with("Hi Sister Ngarupe,")
      end
    end

    context "when the parents have different surnames" do
      let(:mother) do
        unit.members.create!(name: "Bentley-Ngarupe, Kim", gender: :female, birthdate: 39.years.ago.to_date,
                             phone_number: "801-555-0202")
      end

      before do
        add_parent(father, 0)
        add_parent(mother, 1)
      end

      it "names each of them" do
        expect(invitation_for(speaker_aged(9)).email_body)
          .to start_with("Dear Brother Ngarupe and Sister Bentley-Ngarupe,")
      end
    end

    context "when a youth has both parents" do
      before do
        add_parent(father, 0)
        add_parent(mother, 1)
      end

      it "speaks to the youth rather than to their parents" do
        youth = speaker_aged(15, phone_number: "801-555-0204", email: "teen@example.com")
        message = invitation_for(youth)

        expect(message.email_body).to start_with("Dear Junior,")
        expect(message.sms_body).to start_with("Hi Junior, this is")
      end

      it "copies the parents rather than addressing them" do
        youth = speaker_aged(15, phone_number: "801-555-0204", email: "teen@example.com")
        message = invitation_for(youth)

        expect(message.email_recipients).to eq(["teen@example.com"])
        expect(message.email_copied).to eq(%w[davis@example.com kim@example.com])
        expect(message.mailto_url).to include("cc=davis@example.com,kim@example.com")
      end

      it "tells the youth their parents are on the message" do
        youth = speaker_aged(15, phone_number: "801-555-0204", email: "teen@example.com")
        message = invitation_for(youth)

        expect(message.email_body).to include("We have copied Davis and Kim on this message")
        expect(message.sms_body).to include("We have included Davis and Kim on this text")
      end

      it "puts the youth first on the thread, ahead of their parents" do
        youth = speaker_aged(15, phone_number: "801-555-0204")

        expect(invitation_for(youth).sms_numbers).to eq(%w[8015550204 8015550201 8015550202])
      end

      it "writes to the parents when the youth has no email of their own" do
        youth = speaker_aged(15, phone_number: "801-555-0204")
        message = invitation_for(youth)

        expect(message.email_recipients).to eq(%w[davis@example.com kim@example.com])
        expect(message.email_copied).to be_empty
      end
    end

    context "when a message is about a child rather than to them" do
      before do
        add_parent(father, 0)
        add_parent(mother, 1)
      end

      it "refers to a boy as him" do
        expect(invitation_for(speaker_aged(9)).sms_body).to end_with("We would love to hear from him.")
      end

      it "refers to a girl as her" do
        daughter = speaker_aged(9)
        daughter.update!(gender: :female)

        expect(invitation_for(daughter).sms_body).to end_with("We would love to hear from her.")
      end

      it "keeps the sentence when the directory has no gender on record" do
        child = speaker_aged(9)
        child.update_column(:gender, nil)

        expect(invitation_for(child).sms_body).to end_with("We would love to hear from them.")
      end

      it "still speaks to a youth in the second person" do
        youth = speaker_aged(15, phone_number: "801-555-0204")

        expect(invitation_for(youth).sms_body).to include("We would love to hear from you.")
      end
    end

    context "when the speaker is an adult" do
      before do
        add_parent(father, 0)
        add_parent(mother, 1)
      end

      it "speaks to them alone" do
        adult = speaker_aged(40, phone_number: "801-555-0205", email: "adult@example.com")
        message = invitation_for(adult)

        expect(message.email_body).to start_with("Dear Junior,")
        expect(message.sms_numbers).to eq(["8015550205"])
        expect(message.email_recipients).to eq(["adult@example.com"])
        expect(message.email_copied).to be_empty
        expect(message.email_body).not_to include("copied")
      end
    end
  end
end
