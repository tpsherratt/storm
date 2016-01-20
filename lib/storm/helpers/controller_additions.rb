module Storm
  module Helpers
    module ControllerAdditions

      # Little bit of magic so reduce our typing a bit...
      # In the top of your controllers you can do:
      #     mngr MyEngineNamespace::MyManagaer
      # to have that manager automatically available in @mngr in your actions.
      def mngr(clazz)
        self.class_exec do
          before_filter -> {
            raise Storm::Error.new("#{clazz.name} is not a manager") unless clazz < Storm::BaseManager
            @mngr = clazz.new
          }
        end
      end   

    end
  end
end

if defined? ActionController::Base
  ActionController::Base.class_eval do
    extend Storm::Helpers::ControllerAdditions
  end
end