# config/routes.rb
Rails.application.routes.draw do
  devise_for :users
  root 'dashboard#index'

  get 'dashboard', to: 'dashboard#index'


  resources :bank_connections do
    member do
      post :poll_status      # Poll for consent approval
      post :refresh          # Refresh access token
      post :revoke           # Revoke access token
      post :sync             # Sync account data
      
      # Bill payment routes
      get :bill_categories   # Get bill categories
      get 'billers/:category_id' => 'bank_connections#billers'  # Get billers for category
      get 'validate_bill/:category_id/:biller_id/:bill_reference' => 'bank_connections#validate_bill'
      post 'pay_bill/:category_id/:biller_id/:bill_reference' => 'bank_connections#pay_bill'
      
      # Transfer routes
      post :transfer_enquiry   # Check transfer destination
      post :initiate_transfer  # Initiate transfer
    end
  end
  
  # Webhook endpoints for Open Banking callbacks
  namespace :webhooks do
    namespace :open_banking do
      post :transfer_status    # Transfer status updates
      post :consent_status     # Consent status updates
    end
  end
  
  get '/open_banking/callback', to: 'bank_connections#callback'

  # resources :credit_scores, only: [:index, :show] do
  #   collection do
  #     post :calculate
  #     post :refresh
  #   end
  # end
  get 'credit_scores/calculate', to: 'credit_scores#calculate', as: 'calculate_credit_scores'
  post 'credit_scores/calculate', to: 'credit_scores#calculate'
  post 'credit_scores/refresh', to: 'credit_scores#refresh', as: 'refresh_credit_scores'
  resources :credit_scores, only: [:index, :show]

  resources :loan_applications do
    member do
      patch :accept_terms
      patch :upload_documents
    end
  end

  resources :loan_products, only: [:index, :show]


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
    resources :loan_applications, only: [:index, :show, :update] do
      member do
        patch :approve
        patch :reject
        patch :disburse
      end
    end
    resources :loan_products
  end

  # Health check
  get '/health', to: 'application#health'
end