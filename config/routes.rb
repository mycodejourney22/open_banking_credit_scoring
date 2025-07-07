# config/routes.rb
Rails.application.routes.draw do
  devise_for :users
  root 'dashboard#index'

  resources :bank_connections do
    member do
      post :sync
    end
  end
  
  get '/open_banking/callback', to: 'bank_connections#callback'

  resources :credit_scores, only: [:index, :show] do
    collection do
      post :calculate
    end
  end

  resources :credit_applications

  # API routes for mobile app (future)
  namespace :api do
    namespace :v1 do
      resources :users, only: [:show, :update]
      resources :credit_scores, only: [:index, :show]
      resources :bank_connections, only: [:index, :show]
    end
  end

  # Admin routes (future)
  namespace :admin do
    resources :users
    resources :credit_applications
    root 'dashboard#index'
  end

  # Health check
  get '/health', to: 'application#health'
end