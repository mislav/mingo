class Mingo
  module Callbacks
    def self.included(base)
      base.extend ActiveModel::Callbacks
      base.send :define_model_callbacks, :create, :save, :update, :destroy
    end
    
    def save(*args)
      action = persisted? ? 'update' : 'create'
      send(:"_run_#{action}_callbacks") do
        _run_save_callbacks { super }
      end
    end

    def destroy
      _run_destroy_callbacks { super }
    end
  end
end
