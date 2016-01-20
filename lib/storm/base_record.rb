require 'active_record'

# module so we can add functionality to all record classes as required
module Storm
  class BaseRecord < ActiveRecord::Base
    self.abstract_class = true

    # soft delete magic
    include Storm::Trashable
  end
end