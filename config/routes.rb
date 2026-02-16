Rails.application.routes.draw do
  namespace :api do
    get "health", to: "health#show"
    resources :transactions, only: [:index, :create]
    post "transactions/import", to: "transactions#import"
  end
end
