class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home ]

  def home
    @projects = [
      {
        title: "Sipfolio",
        description: "A social cocktail app where users discover, create, and share AI-enhanced recipes, with gamified rewards to drive engagement.",
        img_url: "dark-waves",
        tech_stack: "Ruby-on-Rails . JavaScript . Ruby . PostgreSQL",
        project_url: "https://www.sipfolio.rocks",
        github_url: "https://github.com/chifury/rails-mister-cocktail"
      },
      {
        title: "Water",
        description: "An app about how cool water is.",
        img_url: "tech-city",
        tech_stack: "Ruby-on-Rails . JavaScript . React . PostgreSQL",
        project_url: "https://www.sipfolio.rocks",
        github_url: "https://github.com/chifury/rails-mister-cocktail"
      },
    ]
  end
end
