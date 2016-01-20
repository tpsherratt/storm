module Storm
  # base exception for all others to inherit from
  class Error < StandardError; end

  # exception to raise when loading of managers fails
  class ManagerInitializationError < Error; end
  # when we try to find a non-existant record
  class RecordNotFound < Error; end
  # when trying to save something that's not valid
  class InvalidRecordError < Error; end
  # when trying to instantiate an object
  class ObjectInitializationError < Error; end
  # when trying to save an obj that clashes on a unique col
  class NonUniqueRecordError < Error; end
  
  class UnknownAttributeError < Error; end
end