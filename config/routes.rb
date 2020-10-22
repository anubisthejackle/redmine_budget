get '/deliverables', to: 'deliverables#index'

get '/deliverables/:copy_from/copy', to: 'deliverables#new', as: 'copy_deliverable'
get '/deliverables/context_menu', to: 'deliverables#context_menu'
post '/deliverables/calculator', to: 'deliverables#calculator', as: 'deliverable_calculator'
post '/deliverables/update_form', to: 'deliverables#update_form'
delete '/deliverables', controller: 'deliverables', action: 'destroy'

resources :deliverables, except: [:new, :create] do
  get 'auto_complete'
  get 'issues'
  post 'assign_issues'
end

resources :projects do
  resources :deliverables, only: [:index, :new, :create, :update]
  get 'issues'
end

resources :deliverable_statuses
resources :deliverable_queries
