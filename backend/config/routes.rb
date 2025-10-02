Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :transactions do
        collection do
          post :import
          get :active_imports
          get 'import_status/:id', action: :import_status, as: :import_status
          post 'cancel_import/:id', action: :cancel_import, as: :cancel_import
          post :bulk_categorize
          get :review_dashboard
          delete :destroy_all
        end
      end

      resources :categories, only: [:index, :create, :show, :update, :destroy]

      resources :rules do
        member do
          post :apply
        end
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
