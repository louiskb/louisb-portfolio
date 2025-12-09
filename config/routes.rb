Rails.application.routes.draw do
  get 'blog_posts/index'
  get 'blog_posts/show'
  get 'blog_posts/new'
  get 'blog_posts/create'
  get 'blog_posts/edit'
  get 'blog_posts/update'
  get 'contacts/new'
  get 'contacts/create'
  devise_for :users

  root to: "pages#home"

  get "/profile", to: "pages#profile", as: "profile"

  resources :projects

  resources :blog_posts

  resources :contacts, only: [:new, :create]
end
