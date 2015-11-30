require 'active_model'
require 'active_support'
require 'action_controller'
require 'action_controller/railtie'
require 'active_model/serializer/version'
require 'active_model/serializer'
require 'active_model_serializers/railtie'
module ActiveModelSerializers
  extend ActiveSupport::Autoload
  autoload :Model
  autoload :Callbacks
  autoload :Logging

  require 'active_model/serializable_resource'
  require 'action_controller/serialization'

  mattr_accessor(:logger) { ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT)) }

  def self.config
    ActiveModel::Serializer.config
  end

  module_function

  # @note
  #   ```ruby
  #   private
  #
  #   attr_reader :resource, :adapter_opts, :serializer_opts
  #   ```
  #
  #   Will generate a warning, though it shouldn't.
  #   There's a bug in Ruby for this: https://bugs.ruby-lang.org/issues/10967
  #
  #   We can use +ActiveModelSerializers.silence_warnings+ as a
  #   'safety valve' for unfixable or not-worth-fixing warnings,
  #   and keep our app warning-free.
  #
  #   ```ruby
  #   private
  #
  #   ActiveModelSerializers.silence_warnings do
  #     attr_reader :resource, :adapter_opts, :serializer_opts
  #   end
  #   ```
  #
  #   or, as specific stopgap, define the attrs in the protected scope.
  def silence_warnings
    verbose = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = verbose
  end
end
