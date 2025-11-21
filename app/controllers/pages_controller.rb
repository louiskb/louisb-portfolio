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
        description: "An app about how cool water is. It's amazing and has many features just to learn about water and a h20 for hydration.",
        img_url: "dark-waves",
        tech_stack: "Ruby-on-Rails . JavaScript . React . PostgreSQL",
        project_url: "https://www.sipfolio.rocks",
        github_url: "https://github.com/chifury/rails-mister-cocktail"
      },
      {
        title: "Fire",
        description: "An app about how cool fire is. It's amazing and has many features just to learn about fire and energy for civilization.",
        img_url: "dark-shapes",
        tech_stack: "Ruby-on-Rails . JavaScript . React . PostgreSQL",
        project_url: "https://www.sipfolio.rocks",
        github_url: "https://github.com/chifury/rails-mister-cocktail"
      }
    ]
    @open_source = [
      {
        title: "Find a Doc Japan",
        description: "An app that connects expats living in Japan with the right doctors.",
        img_url: "cosmos-gaze",
        tech_stack: "Vue.js . JavaScript . PostgreSQL",
        project_url: "https://www.findadoc.jp",
        github_url: "https://github.com/ourjapanlife"
      }
    ]
  end
end
