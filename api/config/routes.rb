Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  namespace :api do
    namespace :v1 do
      resources :transactions, only: [:create, :index] do
        collection do
          post :import
        end
      end
    end
  end
end