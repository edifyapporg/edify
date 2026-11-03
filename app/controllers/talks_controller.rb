class TalksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :upsert
  before_action :authenticate_user!
  before_action :authorize_user
  before_action :set_meeting, except: :index
  before_action :set_talk, only: %i[show edit update destroy move]
  after_action :verify_authorized

  # GET /talks
  def index
    # unscope(:order) is needed to remove the position order inserted by acts_as_list
    @q = current_unit.talks.unscope(:order).sort_by_meeting_date_desc.ransack(params[:q])
    @pagy, @talks = pagy(@q.result.includes(:member, :meeting), items: params[:items])
  end

  # GET /meetings/1/talks/1
  def show
  end

  # GET /meetings/1/talks/new
  def new
    @talk = @meeting.talks.new
  end

  # GET /meetings/1/talks/1/edit
  def edit
  end

  # POST /meetings/1/talks
  def create
    @talk = @meeting.talks.new(talk_params)

    if @talk.save
      respond_to do |format|
        format.html do
          redirect_to @talk, notice: t("controllers.talks_controller.created")
        end

        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("meeting_#{@meeting.id}", partial: "meetings/meeting",
                                                                              locals: { meeting: @meeting })
        end
      end
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /meetings/1/talks/1
  def update
    if @talk.update(talk_params)
      respond_to do |format|
        format.html do
          redirect_to @talk, notice: t("controllers.talks_controller.updated")
        end

        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("meeting_#{@meeting.id}", partial: "meetings/meeting",
                                                                              locals: { meeting: @meeting })
        end
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /meetings/1/talks/1
  def destroy
    @talk.destroy

    respond_to do |format|
      format.html do
        redirect_to talks_url, notice: t("controllers.talks_controller.destroyed")
      end

      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("meeting_#{@talk.meeting.id}_talk_#{@talk.id}")
      end
    end
  end

  # POST /meetings/1/talks/upsert
  # This is an upsert using speaker_name as a unique key
  def upsert
    @talk = @meeting.talks.find_or_initialize_by(speaker_name: talk_params[:speaker_name])
    existing_talk = @talk.persisted?
    @talk.assign_attributes(talk_params)

    if @talk.save
      respond_to do |format|
        format.json do
          status = existing_talk ? :ok : :created
          render json: @talk.to_json, status: status
        end
      end
    else
      respond_to do |format|
        format.json { render json: @talk.errors.full_messages.to_json, status: :unprocessable_content }
      end
    end
  end

  # PATCH /meetings/1/talks/1/move
  def move
    respond_to do |format|
      format.json do
        position = params[:position]&.to_i

        if position.present? && @talk.insert_at(position)
          head :ok
        else
          @talk.errors.add(:position, "was not provided") if position.nil?

          render json: @talk.errors.full_messages.to_json, status: :unprocessable_content
        end
      end
    end
  end

  private

  def set_meeting
    @meeting = current_unit.meetings.find(params.expect(:meeting_id))
  end

  def set_talk
    @talk = @meeting.talks.find(params.expect(:id))
  end

  def talk_params
    params.expect(talk: [:speaker_name, :purpose, :topic])
  end
end
