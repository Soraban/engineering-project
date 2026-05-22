Rails.application.routes.draw do
  devise_for :users,
    path: 'api/v1/auth',
    path_names: { sign_in: 'sign_in', sign_out: 'sign_out', registration: 'sign_up' },
    controllers: {
      sessions: 'api/v1/auth/sessions',
      registrations: 'api/v1/auth/registrations'
    }

  namespace :api do
    namespace :v1 do
      resources :transactions, only: [:index, :show, :create, :update, :destroy] do
        collection do
          put :bulk
          get :export
          get :count
        end
      end
      resources :rules
      resources :anomalies, only: [:index, :update] do
        member do
          patch :resolve
        end
      end
      resources :imports, only: [:create]
      get 'dashboard', to: 'dashboard#index'
    end
  end

  mount ActionCable.server => '/cable'

  get "up" => "rails/health#show", as: :rails_health_check
end
