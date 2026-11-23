class Unit < ApplicationRecord
  has_many :access_requests, dependent: nil
  has_many :households, dependent: :destroy
  has_many :import_jobs, dependent: :destroy
  has_many :meetings, dependent: nil
  has_many :members, dependent: nil
  has_many :users, dependent: nil
  has_many :songs, through: :meetings
  has_many :talks, through: :meetings

  validates :name, presence: true
  validates :name, length: { minimum: 4 }, if: :name?

  # @return [Integer]
  def meeting_count
    meetings.count
  end

  # @return [Integer]
  def member_count
    members.count
  end

  # @return [ActiveSupport::Duration]
  def next_available_sunday
    future_meeting_dates = meetings.future.order(:date).pluck(:date).select(&:sunday?).to_set

    proposed_date = Date.current.next_occurring(:sunday)
    proposed_date += 7.days while proposed_date.in?(future_meeting_dates)

    proposed_date
  end

  # @param [String] title
  # @param [Date] date
  # @return [Song, nil]
  def song_last_sung(title, date)
    return unless title.present? && date.present?

    songs.where("songs.title ilike ?", title)
         .where(meetings: { date: ...date })
         .where.not(song_type: [:prelude, :postlude])
         .order("meetings.date desc")
         .first
  end

  # @param [String] name
  # @param [Date] date
  # @return [Talk, nil]
  def speaker_last_talk(name, date)
    return unless name.present? && date.present?

    talks.where("talks.speaker_name ilike ?", name)
         .where(meetings: { date: ...date })
         .reorder("meetings.date desc")
         .first
  end

  # The members a user sees on the roster. "Hide moved members" is the user's saved preference, and it drops members
  # missing from the unit's most recent import. A unit that has never been imported has no notion of a member who has
  # moved out, so nothing is hidden for one.
  # @param [User] user
  # @return [ActiveRecord::Relation<Member>]
  def visible_members_for(user)
    return members unless user.hide_moved_members? && last_synced_on?

    members.synced_since(last_synced_on)
  end

  # @return [Integer]
  def talk_count
    talks.count
  end
end
