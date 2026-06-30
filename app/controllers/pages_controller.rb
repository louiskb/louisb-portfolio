class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home, :terms_of_service, :privacy_policy, :resume ]

  RESUME_PATH = Rails.root.join("public/docs/louis-bourne-full-stack-developer-resume-feb-2026.pdf").freeze

  def home
    # Owner sees everything; visitors only see published projects.
    scope = user_signed_in? ? Project.all : Project.visible_to_visitors
    @personal_projects = filter_personal_projects(scope)
    @open_source_projects = filter_open_source_projects(scope)
    @stats = HomeStats.new.to_h
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

  # GET /resume — streams the resume PDF as an attachment and fires a
  # visitor-only `resume_downloaded` analytics event. Public so the public can
  # download it (and so the event is instrumented at a real endpoint rather than
  # a static asset link).
  def resume
    track_event("resume_downloaded")
    send_file RESUME_PATH, type: "application/pdf", disposition: "attachment"
  end

  private

  def filter_personal_projects(projects)
    projects.select do |project|
      project.personal_project && project.featured
    end
  end

  def filter_open_source_projects(projects)
    projects.select do |project|
      !project.personal_project && project.featured
    end
  end
end
