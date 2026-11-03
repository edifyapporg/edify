class NotesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_user
  before_action :set_member
  before_action :set_note, only: %i[show edit update destroy]
  after_action :verify_authorized

  # GET /notes
  def index
    @notes = @member.notes
  end

  # GET /notes/1
  def show
  end

  # GET /notes/new
  def new
    @note = Note.new
  end

  # GET /notes/1/edit
  def edit
  end

  # POST /notes
  def create
    @note = @member.notes.build(note_params)

    if @note.save
      respond_to do |format|
        format.html do
          redirect_to @member, notice: t("controllers.notes_controller.created")
        end

        format.turbo_stream do
          render turbo_stream: turbo_stream.prepend(:notes, partial: "notes/note", locals: { note: @note })
        end
      end
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /notes/1
  def update
    if @note.update(note_params)
      respond_to do |format|
        format.html do
          redirect_to @note, notice: t("controllers.notes_controller.updated")
        end

        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(@note, partial: "notes/note", locals: { note: @note })
        end
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /notes/1
  def destroy
    @note.destroy

    respond_to do |format|
      format.html do
        redirect_to member_url(@member)
      end

      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(@note)
      end
    end
  end

  private

  def set_member
    @member = current_unit.members.find(params.expect(:member_id))
  end

  def set_note
    @note = @member.notes.find(params.expect(:id))
  end

  def note_params
    params.expect(note: [:member_id, :date, :content])
  end
end
