require 'rails/railtie'

module ActiveModelSerializers
  class Railtie < Rails::Railtie
    initializer 'active_model_serializers.action_controller' do
      ActiveSupport.on_load(:action_controller) do
        ActiveSupport.run_load_hooks(:active_model_serializers, ActiveModelSerializers)
        include ::ActionController::Serialization
        ActionDispatch::Reloader.to_prepare do
          ActiveModel::Serializer.serializers_cache.clear
        end
      end
    end

    initializer 'active_model_serializers.logger' do
      ActiveSupport.on_load(:active_model_serializers) do
        self.logger = ActionController::Base.logger
      end
    end

    initializer 'active_model_serializers.caching' do
      ActiveSupport.on_load(:action_controller) do
        ActiveModelSerializers.config.cache_store     = ActionController::Base.cache_store
        ActiveModelSerializers.config.perform_caching = Rails.configuration.action_controller.perform_caching
      end
    end

    generators do
      require 'generators/rails/resource_override'
    end
  end
end
