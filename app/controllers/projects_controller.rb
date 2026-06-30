class ProjectsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index, :show ]

  def index
    # Owner sees everything; visitors only see published projects.
    scope = (user_signed_in? ? Project.all : Project.visible_to_visitors).order(:position)
    @personal_projects = filter_personal_projects(scope)
    @open_source_projects = filter_open_source_projects(scope)
  end

  def show
    @project = Project.friendly.find(params[:id])
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
    @project = Project.new(project_params)
    @project.user = current_user

    if @project.save
      redirect_to project_path(@project), notice: "Project was successfully created!"
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

    if @project.update(project_params)
      redirect_to project_path(@project), notice: "Project was successfully edited!"
    else
      render :edit, status: :unprocessable_entity
    end
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
