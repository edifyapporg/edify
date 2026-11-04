class UnitsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_user, only: [:new, :create]
  before_action :set_and_authorize_unit, only: [:song_last_sung, :speaker_last_spoke]
  after_action :verify_authorized

  # GET /unit/new
  def new
    @unit = ::Unit.new
  end

  # POST /unit
  def create
    @unit = ::Unit.new(unit_params)
    current_user.role = :bishopric
    @unit.users << current_user

    if @unit.save
      redirect_to root_path
    else
      render :new, status: :unprocessable_content
    end
  end

  # GET /unit/song_last_sung?title=SongTitle&date=2022-04-10
  def song_last_sung
    title = params[:title]
    date = params[:date].to_date # rubocop:disable Rails/StrongParametersExpect -- blank date is allowed
    previous_song = title.present? && date.present? ? @unit.song_last_sung(title, date) : nil
    duration = date.present? && previous_song.present? ? (date - previous_song.meeting_date).to_i.days : nil

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("last_sung_message",
                                                  partial: "songs/last_sung",
                                                  locals: { title: title, duration: duration })
      end
    end
  end

  # GET /unit/speaker_last_spoke?name=SmithsonViolet&date=2022-04-10
  def speaker_last_spoke
    name = params[:name]
    date = params[:date].to_date # rubocop:disable Rails/StrongParametersExpect -- blank date is allowed
    previous_talk = name.present? && date.present? ? @unit.speaker_last_talk(name, date) : nil
    duration = date.present? && previous_talk.present? ? (date - previous_talk.meeting_date).to_i.days : nil

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("last_spoke_message",
                                                  partial: "talks/last_spoke",
                                                  locals: { name: name, duration: duration })
      end
    end
  end

  private

  def unit_params
    params.expect(unit: [:name])
  end

  # The unit always comes from the signed-in user, never from the request.
  # current_unit is nil for users not yet assigned to a unit, so name the
  # policy explicitly rather than letting Pundit infer it from the record.
  def set_and_authorize_unit
    @unit = current_unit
    authorize @unit, policy_class: ::UnitPolicy
  end
end
