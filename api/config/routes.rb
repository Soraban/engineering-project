Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :transactions, only: [:create, :index] do
        collection do
          post :import
        end
      end
      
      resources :rules
    end
  end
end