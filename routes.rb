Rails.application.routes.draw do
  resources :usagegraphs, path: '/example_path/path'
  resources :analytics, path: '/example_path/path' do collection { get 'api'} end
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
