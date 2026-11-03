class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:show, :edit, :update, :destroy]
  before_action :authorize_user, only: [:show, :edit, :update, :destroy]
  after_action :verify_authorized

  # GET /users
  def index
    authorize ::User

    @users = current_unit.users.where.not(id: current_user).alphabetical.with_attached_avatar
    @access_requests = current_unit.access_requests.unapproved.alphabetical
  end

  # GET /users/1
  def show
  end

  # GET /users/1/edit
  def edit
  end

  # PATCH/PUT /users/1
  def update
    if @user.update(role: params.dig(:user, :role))
      respond_to do |format|
        format.html do
          redirect_to users_path, notice: t("controllers.users_controller.updated")
        end

        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(@user, partial: "users/user", locals: { user: @user })
        end
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /users/1
  def destroy
    @user.destroy

    respond_to do |format|
      format.html do
        redirect_to users_url, notice: t("controllers.users_controller.destroyed")
      end

      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(@user)
      end
    end
  end

  private

  def set_user
    @user = current_user.unit.users.find(params.expect(:id))
  end

  def authorize_user
    authorize @user
  end
end
