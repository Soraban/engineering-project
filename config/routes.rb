Rails.application.routes.draw do
  # Dashboard
  root "dashboard#index"
  get "dashboard", to: "dashboard#index"
  get "dashboard/review", to: "dashboard#review", as: :review_dashboard
  post "dashboard/approve_transaction/:id", to: "dashboard#approve_transaction", as: :approve_transaction
  post "dashboard/bulk_approve", to: "dashboard#bulk_approve", as: :bulk_approve

  # Transactions
  resources :transactions do
    collection do
      get :import
      post :import
      post :bulk_categorize
      get 'import_status/:id', to: 'transactions#import_status', as: :import_status
    end
  end

  # Categorization Rules
  resources :categorization_rules do
    member do
      post :apply
      post :toggle
    end
    collection do
      post :apply
    end
  end

  # Categories
  resources :categories, only: [:index]

  # Anomaly Flags
  post 'anomaly_flags/:id/resolve', to: 'anomaly_flags#resolve', as: :resolve_anomaly_flag

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
  
  # ActionCable for Turbo Streams
  mount ActionCable.server => '/cable'
end
