module Edify
  module Etl
    class ImportManager
      GENDER_MAP = {
        "f" => "female",
        "m" => "male",
      }.freeze

      def self.perform!(import_job)
        new(import_job).perform!
      end

      def initialize(import_job)
        @import_job = import_job
        @raw_member_rows = []
        @raw_households = []
      end

      def perform!
        start_import_job
        extract
        load if errors.empty?
        set_finish_attributes
      end

      private

      attr_reader :import_job
      attr_accessor :raw_member_rows, :raw_households

      delegate :errors, to: :import_job, private: true

      def start_import_job
        import_job.start!
        import_job.touch
      end

      # Which directory was pasted decides both how it is read and what it is saved as.
      def extract
        if import_job.households?
          self.raw_households = ExtractHouseholdData.perform(import_job)
        else
          self.raw_member_rows = ExtractMemberData.perform(import_job)
        end
      end

      def load
        import_job.households? ? save_households : save_members
      end

      def save_households
        import_job.update(status: :loading, succeeded_count: 0, failed_count: 0)

        raw_households.each.with_index(1) do |raw_household, row_index|
          household = ::Household.find_or_initialize_by(unit_id: unit.id, name: raw_household.name)
          household.assign_attributes(address_lines: raw_household.address_lines,
                                      phone_number: raw_household.phone_number,
                                      email: raw_household.email,
                                      synced_on: Date.current)

          if household.save
            replace_household_members(household, raw_household.people)
            import_job.increment!(:succeeded_count)
            import_job.log!("Saved:   #{household.name}")
          else
            import_job.increment!(:failed_count)
            import_job.log!("** Failed: #{household.name} **")
            errors.add(:base, resource_error_object(household, row_index))
          end
        rescue ActiveRecord::ActiveRecordError => e
          import_job.increment!(:failed_count)
          import_job.log!("** Unable to save household for row #{row_index} **")
          errors.add(:base, record_not_saved_error(e, row_index))
        ensure
          import_job.set_elapsed_time!
        end
      end

      # The directory is the source of truth for who lives in a household, so the people are replaced wholesale rather
      # than merged -- someone who has moved out has to disappear rather than linger.
      def replace_household_members(household, people)
        household.household_members.destroy_all

        people.each_with_index do |person, position|
          household.household_members.create!(name: person.name, listed_age: person.listed_age,
                                              parent: person.parent, position: position,
                                              member: member_named(person.name))
        end
      end

      # An individuals import can supply people an earlier household import had no Member for yet.
      def link_household_members
        ::HouseholdMember.unmatched.where(household: unit.households).find_each do |household_member|
          member = member_named(household_member.name)
          household_member.update_column(:member_id, member.id) if member
        end
      end

      # Nil when the unit has two members of the same name, since guessing between them would silently attach a
      # household to the wrong person. Queried rather than read off `unit.members`, whose association cache
      # can predate the rows this very import just wrote.
      def member_named(name)
        @members_by_name ||= ::Member.where(unit_id: unit.id).group_by(&:name)
                                     .transform_values { |matches| matches.one? ? matches.first : nil }
        @members_by_name[name]
      end

      def save_members
        import_job.update(status: :loading, succeeded_count: 0, failed_count: 0)

        raw_member_rows.each.with_index(1) do |raw_member_row, row_index|
          member = ::Member.find_or_initialize_by(
            unit_id: unit.id,
            name: raw_member_row.name,
            birthdate: raw_member_row.birthdate
          )
          gender_indicator = raw_member_row.gender&.downcase&.first
          raw_member_row.gender = GENDER_MAP[gender_indicator]
          member.assign_attributes(raw_member_row.to_h)
          member.synced_on = Date.current

          if member.save
            import_job.increment!(:succeeded_count)
            import_job.log!("Saved:   #{member.name}")
          elsif ignore?(member)
            import_job.increment!(:ignored_count)
            import_job.log!("Ignored: #{member.name}")
          else
            import_job.increment!(:failed_count)
            import_job.log!("** Failed: #{member.name} **")
            errors.add(:base, resource_error_object(member, row_index))
          end
        rescue ActiveRecord::ActiveRecordError => e
          import_job.increment!(:failed_count)
          import_job.log!("** Unable to save member for row #{row_index} **")
          errors.add(:base, record_not_saved_error(e, row_index))
        ensure
          import_job.set_elapsed_time!
        end

        link_household_members
      end

      def set_finish_attributes
        if errors.empty?
          import_job.update(status: :finished, status_text: nil)
          today = Date.current
          unit.first_synced_on ||= today
          unit.last_synced_on = today
          unit.save!
        else
          import_job.update(status: :failed, status_text: nil, error_message: errors.full_messages.to_json)
        end
      end

      def unit
        @unit ||= import_job.unit
      end

      def ignore?(member)
        member.under_age?
      end

      def resource_error_object(record, row_index)
        param_filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
        attributes = param_filter.filter(record.attributes.compact)

        { title: "#{record.class} #{record} could not be saved",
          detail: { row_index: row_index, attributes: attributes, messages: record.errors.full_messages } }
      end

      def record_not_saved_error(error, row_index)
        { title: "Record could not be saved",
          detail: { row_index: row_index, messages: ["The record could not be saved: #{error}"] } }
      end
    end
  end
end
