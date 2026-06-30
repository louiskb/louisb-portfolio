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
    collection do
      patch :reorder
      # AI generation acts on the whole collection (creating a new post).
      get  :ai_new
      post :create_with_ai
    end
    member do
      # AI revision acts on a specific existing post (needs an :id).
      get   :ai_revise
      patch :revise_with_ai
    end
  end

  resources :tags, only: [:create, :destroy]

  resources :contacts, only: [:new, :create]
end
