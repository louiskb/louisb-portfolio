class ProjectsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_owned_project, only: %i[ publish schedule cancel_schedule ]

  def index
    # Owner sees everything; visitors only see published projects. Kept as its
    # own variable (not folded straight into `scope`) so the featured-project
    # pick below can reuse the exact same visibility rule — a signed-out
    # visitor must never be offered a draft/scheduled project as the spotlight.
    visitor_scope = user_signed_in? ? Project.all : Project.visible_to_visitors
    # Eager-load the attachment the cards now read (featured_image) to avoid an N+1 per row.
    scope = visitor_scope.with_attached_featured_image.order(:position)

    # Featured spotlight card, rendered above the personal-projects grid.
    # Prefers a personal project explicitly marked `featured` (the spotlight
    # showcases Louis's own work first), position/recency ordered; falls back
    # to any featured project, then to the most recent visible project of any
    # kind, so the spotlight never goes empty.
    featured_scope = visitor_scope.with_attached_featured_image
    @featured_project = featured_scope.where(personal_project: true, featured: true)
                                       .order(:position, created_at: :desc).first ||
                         featured_scope.where(featured: true).order(:position, created_at: :desc).first ||
                         featured_scope.order(:position, created_at: :desc).first

    @personal_projects = filter_personal_projects(scope)
    @open_source_projects = filter_open_source_projects(scope)
    # Exclude the spotlighted project from whichever group list would contain
    # it, so it never duplicates as the first card in that grid below it. The
    # spotlight has no search/filter to hide behind on this index, so this
    # exclusion applies unconditionally whenever a featured project exists.
    if @featured_project
      @personal_projects = @personal_projects.reject { |project| project.id == @featured_project.id }
      @open_source_projects = @open_source_projects.reject { |project| project.id == @featured_project.id }
    end
  end

  def show
    # Owner sees any project; visitors only resolve published ones (draft/scheduled
    # projects 404 instead of leaking — mirrors the index visibility gate).
    base = user_signed_in? ? Project : Project.visible_to_visitors
    @project = base.friendly.find(params[:id])

    track_event("project_viewed", {
      title: @project.title,
      slug: @project.slug
    })
  end

  # PATCH /projects/reorder — persists drag-and-drop order (owner only).
  # Scoped to current_user.projects so a request can only reorder records it
  # owns (defense-in-depth IDOR guard, even though this is a single-user app).
  #
  # The dragged grid is only a SLICE of the whole collection (the projects
  # index has TWO separate sortable grids — personal and open-source — each
  # posting only its own ids here), so writing raw 0..N indexes would make the
  # two grids collide on the same position values. Instead we permute the
  # slice's OWN position values among its members: collect the positions these
  # records already hold, sort them, and hand them back out in the new drag
  # order. Rows never positioned before (nil) take fresh values after the
  # collection's current maximum, mirroring how Postgres already sorts NULLs
  # last on ORDER BY position ASC.
  def reorder
    ids = reorder_params.fetch(:ids, []).map(&:to_i)
    scoped = current_user.projects.where(id: ids)

    owned_ids = scoped.pluck(:id)
    ordered_ids = ids.select { |id| owned_ids.include?(id) }

    slots = scoped.pluck(:position).compact.sort
    next_free = (current_user.projects.maximum(:position) || -1) + 1
    (ordered_ids.size - slots.size).times { |i| slots << next_free + i }

    ordered_ids.each_with_index do |id, index|
      scoped.where(id: id).update_all(position: slots[index])
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

  # :user_id and :position are deliberately NOT permitted: the owner is always
  # assigned from current_user in #create, and position only ever changes
  # through #reorder — neither should be settable from a form payload.
  def project_params
    params.require(:project).permit(:title, :description, :img_url, :tech_stack, :project_url, :github_url,
                                    :personal_project, :private_repo, :featured,
                                    :featured_image, :status, :scheduled_at)
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
