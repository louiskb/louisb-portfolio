# WHEN APP FIRST GOES LIVE IT'S BETTER TO CREATE NEW PROJECTS IN THE `SEED.RB` FILE. ONCE YOU HAVE AI_BLOG_POSTS THEN IT'S BEST NOT KEEP DROPPING DB AND RE-SEEDING BUT CREATING NEW PROJECTS IN THE APP.
# IF YOU CREATE A NEW PROJECT IN THE APP, SCREENSHOT THE PROJECT CARD IN CASE YOUR DATABASE ON HEROKU GETS ACCIDENTALLY WIPED.

puts "Cleaning the Database..."

User.destroy_all
Project.destroy_all
BlogPost.destroy_all

puts "Database cleaned!"

# User
puts "Creating user..."
users = []

user_1 = User.create!(
  email: ENV["USER_1_USERNAME"],
  password: ENV["USER_1_PASSWORD"]
)
# Update the password in the web app or in `rails console` after seeding completes.
users << user_1

puts "#{users.count} user created!"

# For security, edit the user password in the app after seeding (live & local environments).
puts "🔐 Reminder: Edit the user password in the app after seeding (live / local env accordingly)."

# Personal Projects
puts "Creating personal projects..."
projects = []
personal_projects = []

sipfolio = Project.create!(
  title: "Sipfolio",
  description: "A social cocktail app where users discover, create, and share AI-enhanced recipes, with gamified rewards to drive engagement.",
  img_url: "sipfolio-cocktail-screenshot.jpg",
  tech_stack: "Ruby-on-Rails . Bootstrap . StimulusJS . PostgreSQL . Active Record",
  project_url: "https://www.sipfolio.rocks/",
  github_url: "https://github.com/louiskb/rails-mister-cocktail",
  personal_project: true,
  private_repo: false,
  featured: true,
  user: user_1
)
projects << sipfolio
personal_projects << sipfolio

market_sensei = Project.create!(
  title: "Market Sensei",
  description: "A crypto trading platform that integrates AI-driven education and intuitive tools to make trading simpler and more accessible.",
  img_url: "market-sensei-dashboard-screenshot.jpg",
  tech_stack: "Ruby-on-Rails . Bootstrap . StimulusJS . PostgreSQL . Active Record . OpenAI",
  project_url: "https://www.marketsensei.app/",
  # github_url: "https://github.com/louiskb/market-sensei",
  # Github repo is private so need to make this dynamic on the frontend.
  github_url: "https://github.com/louiskb/market-sensei",
  personal_project: true,
  private_repo: true,
  featured: true,
  user: user_1
)
projects << market_sensei
personal_projects << market_sensei

dokodemo_fit = Project.create!(
  title: "Dokedemo Fit",
  description: "An AI-powered app creating personalized exercise routines based on home equipment, with multiple plans for any occasion.",
  img_url: "dokodemo-fit-routines-screenshot.jpg",
  tech_stack: "Ruby-on-Rails . Bootstrap . StimulusJS . PostgreSQL . Active Record . OpenAI",
  project_url: "https://dokodemo-fit-66811301c708.herokuapp.com/",
  github_url: "https://github.com/louiskb/DokodemoFit",
  personal_project: true,
  private_repo: false,
  featured: true,
  user: user_1
)
projects << dokodemo_fit
personal_projects << dokodemo_fit

puts "#{personal_projects.count} personal projects created!"

# Projects with open source contributions.
puts "Creating projects with open source contributions..."
open_source = []

find_a_doc = Project.create!(
  title: "Find a Doc Japan ",
  description: "An app that connects expats living in Japan with the right doctors.",
  img_url: "findadoc-map-screenshot.jpg",
  tech_stack: "Vue.js . JavaScript . Vitest",
  project_url: "https://www.findadoc.jp/",
  github_url: "https://github.com/ourjapanlife",
  personal_project: false,
  private_repo: false,
  featured: true,
  user: user_1
)
projects << find_a_doc
open_source << find_a_doc

puts "#{open_source.count} project(s) with open source contributions created! "

puts "#{projects.count} total projects created!"

puts "Creating blog posts..."

blog_posts = []

blog_post_1 = BlogPost.create!(
  title: "Build Rails Contact Forms",
  description: "Step‑by‑step guide to creating a Ruby on Rails contact form that validates input, sends notification and confirmation emails with Action Mailer, and shows success or error alerts on your page.",
  img_url: "contact-form-ruby.jpg",
  tags: "Rails 7 . ActionMailer . Gmail . Heroku . Contact Form . Tutorial",
  html_content: "<h2>How to Build a Ruby on Rails Contact Form With Action Mailer</h2> <p>A well-designed contact form is essential for any Ruby on Rails portfolio or production app. In this guide you will build a contact form that saves submissions, shows clear success and error alerts, emails you when someone gets in touch, and sends the user a confirmation email so they know their message was received.</p> <p>This tutorial uses Action Mailer in Rails 7+, Simple Form for cleaner form markup, and an SMTP provider (such as Proton, Gmail, or another service) for sending email.</p>",
  # Edit this blog post with the rest of the code in the web app after seeds have run successfully!
  user: user_1
)
blog_posts << blog_post_1

puts "#{blog_posts.count} blog post(s) created!"
puts "🤓 Reminder: Edit the first blog_post with the rest of the code (:html_content) in the web app."
puts "Seed successful! ✅"
