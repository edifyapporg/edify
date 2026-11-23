Rails.application.routes.draw do
  draw :madmin

  authenticate :user, ->(u) { u.admin? } do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  devise_for :users, controllers: {
    registrations: "users/registrations",
  }

  resources :access_requests, only: [:new, :create, :destroy] do
    get :review, on: :member
    put :approve, on: :member
    put :reject, on: :member
  end

  resources :announcements, only: [:index]
  resources :import_jobs, only: [:index, :show, :new, :create, :destroy]

  namespace :members do
    resources :possible_duplicates, only: [:index] do
      collection do
        get :summary
        put :merge
        post :dismiss
      end
    end
  end

  resources :meetings do
    member do
      get :edit_contributors
      patch :update_contributors
    end
    collection do
      get :music
      post :upsert
    end
    resources :talks, except: :index do
      patch :move, on: :member
      post :upsert, on: :collection
    end
    resources :songs, except: :index
  end

  resources :members do
    patch :moved_filter, on: :collection
    post :upsert, on: :collection
    resources :notes
  end

  resources :notifications, only: [:index]
  resources :talks, only: [:index]

  resource :unit, only: [:new, :create] do
    get :song_last_sung
    get :speaker_last_spoke
  end

  resources :users, only: [:index, :show, :edit, :update, :destroy]

  namespace :settings do
    get :preferences
    get :avatar
    get :password
    put :update
    put :remove_avatar

    resources :api_tokens, only: [:index, :create] do
      patch :revoke, on: :member
    end
  end

  namespace :api, defaults: { format: :json } do
    namespace :v1 do # rubocop:disable Naming/VariableNumber
      get "meetings", to: "meetings#index"
      get "members", to: "members#index"
      get "meetings/:date", to: "meetings#show", as: :meeting
      get "songs/recent", to: "songs#recent"
      get "speakers/stale", to: "speakers#stale"

      match "*unmatched", to: "base#route_not_found", via: :all
    end
  end

  match "/mcp", to: "mcp#handle", via: [:get, :post, :delete]

  namespace :webhooks do
    resources :mailgun_events, only: [:create]
  end

  root to: "home#index"
  get "/privacy", to: "home#privacy"
  get "/terms", to: "home#terms"
  get "/onboard", to: "onboard#start"
  post "impersonate/start/:id", to: "impersonate#start", as: "impersonate_start"
  post "impersonate/stop", to: "impersonate#stop", as: "impersonate_stop"
end
