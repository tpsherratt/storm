module Storm
  ##############
  # A class for our models to inherit from.
  #
  # Provides:
  # - definition of attrs like: class Ting < Storm::BaseModel; attributes :id, :my_attr; end
  # - instantiation from an attrs hash
  # - my_instance.attributes # => { id: 1, my_attr: "hi" }
  # - tracking of new vs persisted record
  # - protection against manual changing of IDs (important as with current implementation
  #   that's the only way to track domain obj - record obj link. To improve)
  #
  # Todo (tentative plan):
  # - track dirty attrs (to improve query speed)
  # - allow updating of ids, with dirty attr stuff, in record obj, in BaseManager
  #
  # See https://github.com/rails/rails/tree/master/activemodel
  #
  # TS
  #####
  class BaseModel
    # This is a list of stuff that I think we might want... So far I've left it
    # all commented, as I don't want to add shit we don't need. Let's what we come
    # up against, and see what active* might help us. TS

    # include ActiveModel::Model
    # track changes to attributes
    # include ActiveModel::Dirty
    # model name introspection
    # extend ActiveModel::Naming
    # XXX.to_json
    #include ActiveModel::Serialization::JSON


    # magic to allow us to easily generate attribute methods
    include ActiveModel::AttributeMethods

    # where attributes live
    attr_reader :attributes

    # use ActiveModel::AttributeMethods to define setters for our attrs
    attribute_method_suffix "="

    # class instance variable to store the manager
    @manager_class

    # method to set attributes on a Storm model eg:
    # class User; attributes :my_sweet_att; end
    def self.attributes(attr, *attrs)
      attrs << attr
      define_attribute_methods attrs
    end
    private_class_method :attributes


    def self.manager
      return @manager_class unless @manager_class.nil?

      begin
        @manager_class = "#{self.name}Manager".constantize
        return @manager_class
      rescue
        error = "Could not find manager class (#{@manager_class}). If it has non-standard naming /
          you need to set it in your domain model with `set_manager_class MyManager`"
        raise Storm::ManagerInitializationError.new(error)
      end
    end


    # initializer, take attrs in a hash
    def initialize(attributes=nil, options={})
      raise Error.new("Storm::BaseModel is abstract") if self.class == Storm::BaseModel

      init_internals
      set_attributes(attributes, options) if attributes
    end


    # cast this to another class type (as far as Storm is concerned)
    # for use with classes that inherit from eachother
    # TODO: add attribute filtering depending on what is available on the new class
    def becomes(clazz)
      new_obj = clazz.new(self.attributes)
      new_obj.instance_variable_set(:@new_record, self.instance_variable_get(:@new_record))
      new_obj.instance_variable_set(:@persisted_id, self.instance_variable_get(:@persisted_id))
      new_obj.instance_variable_set(:@trashed, self.instance_variable_get(:@trashed))
      new_obj
    end

    private

    def self.set_manager_class(manager_class)
      error = "No such class #{manager_class}"
      raise ManagerInitializationError.new(error) unless manager_class.is_a? Class      
      @manager_class = manager_class
    end

    # iterate through hash and assign
    def set_attributes(attrs, options)
      raise ObjectInitializationError.new("argument must be a hash") unless attrs.is_a? Hash

      attrs.symbolize_keys!

      attrs.each do |k, v|
        set_attribute(k, v)
      end
    end

    def set_attribute(k, v)
      public_send("#{k}=", v)
    rescue NoMethodError => e
      raise e if respond_to? "#{k}="
      raise UnknownAttributeError.new("Unknown attribute '#{k}' for #{self.class}")
    end


    # setup a model, on it's instantiation
    def init_internals
      @new_record = true
      @attributes = {}
      @persisted_id = nil
      @trashed = false
    end

    # attr_writers, via ActiveModel::AttributeMethods/method_missing
    def attribute=(attr, value)
      @attributes[attr.to_sym] = value
    end

    # attr_readers, via ActiveModel::AttributeMethods/method_missing
    def attribute(attr)
      @attributes[attr.to_sym]
    end
  end
end