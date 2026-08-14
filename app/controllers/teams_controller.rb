class TeamsController < InternalController
  include ModalResponses

  MODAL_FRAME = "team_modal".freeze

  before_action :set_team, only: %i[show edit update destroy badges pages events applications]

  # GET /teams
  def index
    @q = policy_scope(Team).ransack(params[:q])
    @q.sorts = "team_types.name asc" if @q.sorts.empty?

    teams = @q.result(distinct: true).includes(:team_type).order("team_type.name": :asc, name: :asc)

    unless params[:filter] == "all"
      teams = teams.where(id: current_user.person.teams.select(:id))
    end

    @teams = teams.page(params[:page]).includes(:team_type, :people)
  end

  # GET /teams/1
  def show
    @is_member = current_user.admin? || current_user.architect? || @team.people.include?(current_user.person)
    return render partial: "teams/modal_details", locals: { team: @team } if modal_frame_request?(MODAL_FRAME)

    render "show_public" unless @is_member
    if GatherPack::Features.enabled?(:qa)
      @recent_questions = @team.questions.where(closed: false).order(created_at: :desc).limit(5)
    end
  end

  # GET /teams/1/badges
  def badges
    @badges = policy_scope(@team.badges).order(name: :asc).page(params[:page])
  end

  # GET /teams/1/pages
  def pages
    @pages = policy_scope(@team.pages).order(created_at: :desc).page(params[:page])
  end

  # GET /teams/1/events
  def events
    @events = policy_scope(@team.events).order(start_time: :desc).page(params[:page])
  end

  # GET /teams/1/applications
  def applications
    @pending_applications = @team.membership_applications.pending.includes(:person).order(created_at: :desc)
  end

  # GET /teams/new
  def new
    @team = authorize Team.new
    render partial: "teams/modal_form", locals: { team: @team } if modal_frame_request?(MODAL_FRAME)
  end

  # GET /teams/1/edit
  def edit
    authorize @team
    render partial: "teams/modal_form", locals: { team: @team } if modal_frame_request?(MODAL_FRAME)
  end

  # POST /teams
  def create
    @team = authorize Team.new(team_params)

    if @team.save
      if modal_submission?
        render turbo_stream: [
          turbo_stream.prepend("teams", partial: "teams/team", locals: { team: @team }),
          modal_flash("success", "Team was successfully created.")
        ]
      else
        redirect_to @team, notice: "Team was successfully created."
      end
    elsif modal_submission?
      render partial: "teams/modal_form", locals: { team: @team }, status: :unprocessable_entity
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /teams/1
  def update
    if authorize(@team).update(permitted_attributes(@team))
      if modal_submission?
        render turbo_stream: [
          turbo_stream.replace(@team, partial: "teams/team", locals: { team: @team }),
          modal_flash("success", "Team was successfully updated.")
        ]
      else
        redirect_to @team, notice: "Team was successfully updated.", status: :see_other
      end
    elsif modal_submission?
      render partial: "teams/modal_form", locals: { team: @team }, status: :unprocessable_entity
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /teams/1
  def destroy
    authorize @team
    @team.destroy!

    if modal_submission?
      render turbo_stream: [
        turbo_stream.remove(@team),
        modal_flash("success", "Team was successfully destroyed.")
      ]
    else
      redirect_to teams_url, notice: "Team was successfully destroyed.", status: :see_other
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_team
    @team = policy_scope(Team).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    raise Pundit::NotAuthorizedError
  end

  # Only allow a list of trusted parameters through.
  def team_params
    permitted = [ :name, :parent_id, :color, :description, :team_type_id, :join_permission, person_ids: [] ]
    # The tag picker can name a type that doesn't exist yet, but only for
    # people who are allowed to create team types in the first place.
    permitted.unshift(:new_team_type_name) if TeamTypePolicy.new(current_user, TeamType).create?

    params.require(:team).permit(*permitted)
  end
end
