Rails.application.routes.draw do
  namespace :api do
    get "health", to: "health#show"

    resources :transactions, only: [ :index, :create, :update, :destroy ] do
      collection do
        get :review
        post :import
        patch :bulk_update
      end
    end

    resources :rules, only: [ :index, :create ]
  end
end
