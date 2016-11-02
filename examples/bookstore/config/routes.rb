Rails.application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".


  namespace :api do
    namespace :v1 do
      resources :authors, except: [:new, :edit], param: :author_id
      resources :books, except: [:new, :edit], param: :book_id
      resources :genres, except: [:new, :edit], param: :genre_id
      resources :orders, except: [:new, :edit], param: :order_id
      resources :users, except: [:new, :edit], param: :user_id
    end
  end

  get '/terms_of_service' => 'home#terms_of_service'
end
