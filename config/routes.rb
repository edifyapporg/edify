Rails.application.routes.draw do
  draw :madmin

  authenticate :user, ->(u) { u.admin? } do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions",
  }

  resources :access_requests, only: [:new, :create, :destroy] do
    get :review, on: :member
    put :approve, on: :member
    put :reject, on: :member
  end

  resources :announcements, only: [:index]
  resources :import_jobs, only: [:index, :show, :new, :create, :destroy]

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
    post :upsert, on: :collection
    resources :notes
  end

  resources :notifications, only: [:index]
  resources :talks, only: [:index]

  resources :units, only: [:new, :edit, :create, :update] do
    get :song_last_sung, on: :member
    get :speaker_last_spoke, on: :member
  end

  resources :users, only: [:index, :show, :edit, :update, :destroy]

  namespace :settings do
    get :preferences
    get :avatar
    get :password
    put :update
    put :remove_avatar
  end

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
