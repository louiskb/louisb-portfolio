Rails.application.routes.draw do

  devise_for :users

  root to: "pages#home"

  get "/profile", to: "pages#profile", as: "profile"
  get "/terms_of_service", to: "pages#terms_of_service", as: "terms_of_service"
  get "/privacy_policy", to: "pages#privacy_policy", as: "privacy_policy"

  resources :projects do
    collection { patch :reorder }
  end

  resources :blog_posts do
    collection { patch :reorder }
  end

  resources :contacts, only: [:new, :create]
end
