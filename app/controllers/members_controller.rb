class MembersController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :upsert
  before_action :authenticate_user!
  before_action :authorize_user
  before_action :set_member, only: %i[show edit update destroy]
  after_action :verify_authorized

  # GET /members
  def index
    @q = visible_members.with_last_talk_date.ransack(params[:q])
    @q.sorts = ["name asc"] if @q.sorts.empty?
    @pagy, @members = pagy(@q.result.includes(:unit), items: params[:items])
  end

  # GET /members/1
  def show
  end

  # GET /members/new
  def new
    @member = current_unit.members.new
  end

  # GET /members/1/edit
  def edit
  end

  # POST /members
  def create
    @member = current_unit.members.new(member_params)

    if @member.save
      respond_to do |format|
        format.html do
          redirect_to @member, notice: t("controllers.members_controller.created")
        end

        format.turbo_stream do
          render turbo_stream: turbo_stream.prepend(:members, partial: "members/member", locals: { member: @member })
        end
      end
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /members/1
  def update
    if @member.update(member_params)
      respond_to do |format|
        format.html do
          redirect_to @member, notice: t("controllers.members_controller.updated")
        end

        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(@member, partial: "members/member", locals: { member: @member })
        end
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /members/1
  def destroy
    @member.destroy

    respond_to do |format|
      format.html do
        redirect_to members_url, notice: t("controllers.members_controller.destroyed")
      end

      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(@member)
      end
    end
  end

  # POST /members/upsert
  # This is an upsert using name and birthdate as a composite unique key
  def upsert
    @member = current_unit.members.find_or_initialize_by(name: member_params[:name],
                                                         birthdate: member_params[:birthdate])
    existing_member = @member.persisted?
    @member.assign_attributes(member_params)

    if @member.save
      respond_to do |format|
        format.json do
          if existing_member
            status = :ok
            synced_on = Date.current
          else
            status = :created
            synced_on = @member.created_at.to_date
          end

          @member.update_column(:synced_on, synced_on)
          render json: @member.to_json, status: status
        end
      end
    else
      respond_to do |format|
        format.json { render json: @member.errors.full_messages.to_json, status: :unprocessable_content }
      end
    end
  end

  private

  def set_member
    @member = current_unit.members.find(params[:id])
  end

  # "Hide moved members" is a saved user preference rather than a URL filter, so
  # the roster is narrowed before Ransack sees it and the choice survives
  # sorting, searching and paging. A unit that has never been imported has no
  # notion of a member who has moved out, so nothing is hidden for one.
  def visible_members
    return current_unit.members unless current_user.hide_moved_members? && current_unit.last_synced_on?

    current_unit.members.synced_since(current_unit.last_synced_on)
  end

  def member_params
    params.expect(
      member: [:birthdate,
               :email,
               :gender,
               :name,
               :paused_on,
               :paused_by,
               :paused_until,
               :phone_number],
    )
  end
end
