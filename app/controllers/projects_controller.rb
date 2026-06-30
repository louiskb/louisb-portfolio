class ProjectsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_owned_project, only: %i[ publish schedule cancel_schedule ]

  def index
    # Owner sees everything; visitors only see published projects.
    scope = (user_signed_in? ? Project.all : Project.visible_to_visitors).order(:position)
    @personal_projects = filter_personal_projects(scope)
    @open_source_projects = filter_open_source_projects(scope)
  end

  def show
    @project = Project.friendly.find(params[:id])

    track_event("project_viewed", {
      title: @project.title,
      slug: @project.slug
    })
  end

  # PATCH /projects/reorder — persists drag-and-drop order (owner only).
  # Scoped to current_user.projects so a request can only reorder records it
  # owns (defense-in-depth IDOR guard, even though this is a single-user app).
  def reorder
    reorder_params.fetch(:ids, []).map(&:to_i).each_with_index do |id, index|
      current_user.projects.where(id: id).update_all(position: index)
    end
    head :ok
  end

  def new
    @project = Project.new
    @featured_personal_projects_count = filter_featured_personal_projects(Project.all)
    @featured_open_source_projects_count = filter_featured_open_source_projects(Project.all)
  end

  def create
    status, scheduled_at = resolve_publish_intent(
      params.dig(:project, :status),
      params.dig(:project, :scheduled_at)
    )
    @project = Project.new(project_params.merge(status: status, scheduled_at: scheduled_at))
    @project.user = current_user

    if @project.save
      redirect_to project_path(@project), notice: publish_notice(status, scheduled_at, action: :created)
    else
      render "new", status: :unprocessable_entity
    end
  end

  def edit
    @project = Project.friendly.find(params[:id])
    @featured_personal_projects_count = filter_featured_personal_projects(Project.all)
    @featured_open_source_projects_count = filter_featured_open_source_projects(Project.all)
  end

  def update
    @project = Project.friendly.find(params[:id])
    status, scheduled_at = resolve_publish_intent(
      params.dig(:project, :status),
      params.dig(:project, :scheduled_at)
    )

    if @project.update(project_params.merge(status: status, scheduled_at: scheduled_at))
      redirect_to project_path(@project), notice: publish_notice(status, scheduled_at, action: :updated)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # PATCH /projects/:id/publish — publishes a draft or scheduled project now.
  def publish
    @project.publish!
    redirect_to project_path(@project), notice: "Project published successfully."
  end

  # PATCH /projects/:id/schedule — sets a future publish time.
  def schedule
    parsed_time = parse_future_time(params[:scheduled_at])

    if parsed_time.nil?
      redirect_to project_path(@project),
        alert: "Please choose a date and time in the future to schedule."
      return
    end

    @project.schedule!(parsed_time)
    redirect_to project_path(@project),
      notice: "Project scheduled for #{parsed_time.strftime("%d %b %Y at %H:%M")}."
  end

  # PATCH /projects/:id/cancel_schedule — reverts a scheduled project to draft.
  def cancel_schedule
    @project.cancel_schedule!
    redirect_to project_path(@project), notice: "Schedule cancelled. Project reverted to draft."
  end

  def destroy
    @project = Project.friendly.find(params[:id])

    if @project.destroy
      redirect_to projects_path, notice: "Project was successfully deleted!", status: :see_other
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  # Scoped to current_user.projects so a publish/schedule/cancel request can only
  # act on a project the signed-in owner owns (defense-in-depth IDOR guard,
  # matching the reorder pattern).
  def set_owned_project
    @project = current_user.projects.friendly.find(params[:id])
  end

  # Parses the split button's status + datetime-local scheduled_at into the
  # [status_symbol, scheduled_at_or_nil] pair persisted on the record.
  #
  #   "published"                       -> publish now
  #   "scheduled" + future scheduled_at -> schedule
  #   "scheduled" + blank/past time     -> draft  (safer than silently publishing)
  #   "draft" / anything else           -> draft
  def resolve_publish_intent(raw_status, raw_scheduled_at)
    status = (raw_status.presence || "draft").to_sym

    if status == :scheduled
      parsed = parse_future_time(raw_scheduled_at)
      return [ :draft, nil ] if parsed.nil?

      return [ :scheduled, parsed ]
    end

    [ status, nil ]
  end

  # Returns a parsed Time only when the input is present and strictly in the
  # future; otherwise nil. Tolerates unparseable input (returns nil).
  def parse_future_time(raw)
    return nil if raw.blank?

    parsed = Time.zone.parse(raw.to_s)
    parsed if parsed && parsed > Time.current
  rescue ArgumentError
    nil
  end

  # Human-readable flash notice describing what happened to the project.
  def publish_notice(status, scheduled_at, action:)
    base = action == :created ? "Project saved" : "Project updated"

    case status.to_sym
    when :published then "#{base} and published."
    when :scheduled then "#{base} and scheduled for #{scheduled_at.strftime("%d %b %Y at %H:%M")}."
    else                 "#{base} as draft."
    end
  end

  def project_params
    params.require(:project).permit(:title, :description, :img_url, :tech_stack, :project_url, :github_url,
                                    :user_id, :personal_project, :private_repo, :featured,
                                    :featured_image, :status, :scheduled_at, :position)
  end

  def reorder_params
    params.permit(ids: [])
  end

  def filter_personal_projects(projects)
    projects.select do |project|
      project.personal_project
    end
  end

  def filter_open_source_projects(projects)
    projects.select do |project|
      !project.personal_project
    end
  end

  def filter_featured_personal_projects(projects)
    featured_projects = projects.select do |project|
      project.personal_project && project.featured
    end
    featured_projects.count
  end

  def filter_featured_open_source_projects(projects)
    featured_projects = projects.select do |project|
      !project.personal_project && project.featured
    end
    featured_projects.count
  end
end
