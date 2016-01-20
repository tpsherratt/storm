module Storm
  module Trashable
    extend ActiveSupport::Concern
   
    included do
      default_scope { where(trashed_at: nil) }
    end
   
    module ClassMethods
      def trashed
        self.unscoped.where(self.arel_table[:trashed_at].not_eq(nil))
      end
    end

    def trashed?
      !self.trashed_at.nil?
    end
   
    def trash!
      run_callbacks :destroy do
        update_column :trashed_at, Time.now
      end
    end
   
    def recover
      # update_column not appropriate here as it uses the default scope
      update_attribute :trashed_at, nil
    end
  end
end