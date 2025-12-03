Rails.application.routes.draw do
  get 'contacts/new'
  get 'contacts/create'
  devise_for :users

  root to: "pages#home"

  get "/profile", to: "pages#profile", as: "profile"

  resources :projects

  resources :contacts, only: [:new, :create]
end
