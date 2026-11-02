class UnitsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_user
  before_action :set_unit, except: [:new, :create]
  after_action :verify_authorized

  # GET /units/new
  def new
    @unit = ::Unit.new
  end

  # GET /units/1/edit
  def edit
  end

  # POST /units
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

  # PATCH/PUT /units/1
  def update
    if @unit.update(unit_params)
      respond_to do |format|
        format.html do
          redirect_to @unit, notice: t("controllers.units_controller.updated")
        end
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  # GET /units/1/song_last_sung?title=SongTitle&date=2022-04-10
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

  # GET /units/1/speaker_last_spoke?name=SmithsonViolet&date=2022-04-10
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

  def set_unit
    @unit = ::Unit.find(params.expect(:id))
  end
end
