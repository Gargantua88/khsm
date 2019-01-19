Rails.application.routes.draw do
  root 'users#index'

  devise_for :users

  resources :users, only: [:index, :show]

  resources :games, only: [:create, :show] do
    put 'help', on: :member
    put 'answer', on: :member # доп. метод ресурса - ответ на текущий вопрос
    put 'take_money', on: :member # доп. метод ресурса - игрок берет деньги
  end

  resource :questions, only: [:new, :create]
end
