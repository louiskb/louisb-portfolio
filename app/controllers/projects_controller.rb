class ProjectsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index ]

  def index
    @personal_projects = filter_personal_projects(Project.all)
    @open_source_projects = filter_open_source_projects(Project.all)
  end

  def show
    @project = Project.find(params[:id])
  end

  def new
    @project = Project.new
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
    @project = Project.find(params[:id])
  end

  def update
    @project = Project.find(params[:id])

    if @project.update(project_params)
      redirect_to project_path(@project), notice: "Project was successfully edited!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project = Project.find(params[:id])

    if @project.destroy
      redirect_to projects_path, notice: "Project was successfully deleted!", status: :see_other
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def project_params
    params.require(:project).permit(:title, :description, :img_url, :tech_stack, :project_url, :github_url, :user_id, :personal_project, :private_repo, :featured)
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
end
