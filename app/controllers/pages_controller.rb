class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home, :terms_of_service, :privacy_policy ]

  def home
    @personal_projects = filter_personal_projects(Project.all)
    @open_source_projects = filter_open_source_projects(Project.all)
    @contact = Contact.new
  end

  def profile
    @user = current_user
    @projects = Project.all
    @projects_total = Project.all.count
    @personal_projects_count = Project.where(personal_project: true).count
    @non_personal_projects_count = Project.where(personal_project: false).count
    @private_repo_count = Project.where(private_repo: true).count
    @public_repo_count = @projects.count - @private_repo_count
  end

  def terms_of_service
  end

  def privacy_policy
  end

  private

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
