module Storm
  #################
  # Implementation of callbacks for use within managers
  #
  # Provides:
  # - before_xxx and after_xxx callbacks
  # - ability for callback to setup in parent, and callbacks defined in child classes
  #
  # Example usage:
  #
  # class MyClass
  #   include Storm::Callbacks
  #
  #   define_callbacks :save, :destroy
  #
  #   def save(obj)
  #     run_callbacks :save, obj do
  #       # save code...
  #     end
  #   end
  #
  #   def before_save(obj)
  #     puts "about to save #{obj}"
  #   end
  #
  #   def after_save(obj)
  #     puts "finished saving #{obj}"
  #   end
  # end
  #
  ############


  module Callbacks

    module ClassMethods

      def define_callbacks(*cbs)
        @_callbacks = cbs
        setup_class_methods
      end

      def setup_class_methods
        @_callbacks.each do |callback_name|
          define_singleton_method("before_#{callback_name}") do |callback_method|
            @_callback_methods ||= {}
            @_callback_methods["before_#{callback_name}"] ||= []
            @_callback_methods["before_#{callback_name}"] << callback_method
          end

          define_singleton_method("after_#{callback_name}") do |callback_method|
            @_callback_methods ||= {}
            @_callback_methods["after_#{callback_name}"] ||= []
            @_callback_methods["after_#{callback_name}"] << callback_method
          end
        end
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end


    def run_callbacks(callback_name, obj, options={}, &block)
      callback_methods = self.class.instance_variable_get(:@_callback_methods)

      do_not_run = options.has_key?(:if) && options[:if] == false

      run_callback(callback_methods, "before_#{callback_name}", obj) unless do_not_run
      yield
      run_callback(callback_methods, "after_#{callback_name}", obj) unless do_not_run

      true # stop it returning what
    end

    private
    def run_callback(methods, name, obj)
      return if methods.nil?
      return if methods[name].nil?
      methods[name].each{ |method| send(method, obj) }
    end

  end
end