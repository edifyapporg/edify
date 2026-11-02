class MeetingsController < ApplicationController
  include ActionView::RecordIdentifier

  skip_before_action :verify_authenticity_token, only: :upsert
  before_action :authenticate_user!
  before_action :authorize_user
  before_action :set_meeting, only: %i[show edit update destroy edit_contributors update_contributors]
  before_action :set_meetings_and_pagy, only: %i[index music]
  after_action :verify_authorized

  # GET /meetings
  def index
    @meetings_view_object = ::MeetingsViewObject.new(@meetings, view_context, @pagy)
  end

  # GET /meetings/1
  def show
  end

  # GET /meetings/new
  def new
    @meeting = current_unit.meetings.new
  end

  # GET /meetings/1/edit
  def edit
  end

  # POST /meetings
  def create
    @meeting = current_unit.meetings.new(meeting_params)

    if @meeting.save
      respond_to do |format|
        format.html do
          redirect_to meetings_path, notice: t("controllers.meetings_controller.created")
        end

        format.turbo_stream
      end
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /meetings/1
  def update
    if @meeting.update(meeting_params)
      respond_to do |format|
        format.html do
          redirect_to @meeting, notice: t("controllers.meetings_controller.updated")
        end

        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(@meeting,
                                                    partial: "meetings/meeting",
                                                    locals: { meeting: @meeting })
        end
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /meetings/1
  def destroy
    @meeting.destroy

    respond_to do |format|
      format.html do
        redirect_to member_url(@member)
      end

      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(@meeting)
      end
    end
  end

  # GET /meetings/1/edit_contributors
  def edit_contributors
  end

  # PATCH/PUT /meetings/1/update_contributors
  def update_contributors
    respond_to do |format|
      format.turbo_stream do
        if @meeting.update(meeting_program_member_params)
          render turbo_stream: turbo_stream.replace(dom_id(@meeting, :contributors),
                                                    partial: "meetings/contributors",
                                                    locals: { meeting: @meeting })
        else
          render :edit_contributors, status: :unprocessable_content
        end
      end
    end
  end

  # GET /meetings/music
  def music
    use_fluid_container
    @meetings_view_object = ::MeetingsViewObject.new(@meetings, view_context, @pagy)
  end

  # POST /meetings/upsert
  # This is an upsert using date as a unique key
  def upsert
    @meeting = current_unit.meetings.find_or_initialize_by(date: meeting_params[:date])
    existing_meeting = @meeting.persisted?
    @meeting.assign_attributes(meeting_params)

    if @meeting.save
      respond_to do |format|
        format.json do
          status = existing_meeting ? :ok : :created
          render json: @meeting.to_json, status: status
        end
      end
    else
      respond_to do |format|
        format.json { render json: @meeting.errors.full_messages.to_json, status: :unprocessable_content }
      end
    end
  end

  private

  def set_meetings_and_pagy
    @q = current_unit.meetings.ransack(params[:q])
    @q.sorts = ["date desc"] if @q.sorts.empty?
    @pagy, @meetings = pagy(@q.result.includes(:talks, :songs), items: params[:items])
  end

  def set_meeting
    @meeting = current_unit.meetings.find(params.expect(:id))
  end

  def meeting_params
    params.expect(meeting: [:date, :meeting_type, :scheduler_id])
  end

  def meeting_program_member_params
    params.expect(meeting: [*Meeting::CONTRIBUTOR_TITLES.keys])
  end
end
