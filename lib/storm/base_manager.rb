module Storm
  ##################
  # A class for our managers to inheret from.
  #
  # Provides:
  # - Automatic figuring out of domain/record classes (if names conform),
  #   and methods to set them if they don't
  # - For end use
  #   - Loading: :find, :find_by_*, :where, :first, :second, :third, :fourth
  #   - Saving: :save, :save!
  # - For building functionality in subclasses
  #   - persist domain obj to AR (:persist)
  #   - load domain obj from AR (:call_active_record)
  #   - build domain obj from record obj (:build_domain_obj)
  # - Callbacks
  #   - :before_save, :after_save, and :around_save
  #   - :before_create, :after_create, and :around_create
  #   - :before_update, :after_update, and :around_update
  #   - :before_destroy, :after_destroy, and :around_destroy
  #
  #
  # The goal here is to put some separation between the DB and our domain models.
  #
  # Though this is a work in progress, to see what works for us. Aim to keep
  # it as minimal as possible, as this could get messy.
  #
  # We borrow method names etc. from ActiveRecord as much as possible, to keep things
  # nice and familiar.
  #
  # TODO:
  # - Get errors back to domain model when validations fail
  # - Create/Update callbacks
  #
  # TS
  ######
  class BaseManager
    # callbacks - had to write our own mixin for this, as we need slightly different
    # fucntionality to what ActiveModel::Callbacks provides
    include Storm::Callbacks

    # define class instance variables/getters
    @record_class
    @domain_class
    @single_table_inheritance = false
    class << self; attr_reader :record_class, :domain_class end

    # callbacks around save
    define_callbacks :save, :destroy, :create, :update

    # Naming of domain models/managers/record classes is assumed to be consistent
    # (ie. User, UserManager, UserRecord), so here we work out and store the
    # domain model and record class.
    #
    # If you need to break this convention, use the :set_domain_class and/or
    # :set_record_class methods to specify the classes used.
    def initialize
      raise Error.new("Storm::BaseManager is abstract") if self.class == Storm::BaseManager
      # set the instance instance variables from the class instance variables!
      @record_class = self.class.record_class.nil? ? infer_class("Record") : self.class.record_class
      @domain_class = self.class.domain_class.nil? ? infer_class("") : self.class.domain_class
    end

    # TODO: These two methods should be private. Need to rewrite the tests though, innit. TS
    # Allow inheriting classes to define a non-standard Record Class
    def self.set_record_class(record_class)
      error = "No such class #{record_class}"
      raise ManagerInitializationError.new(error) unless record_class.is_a? Class
      @record_class = record_class
    end

    # Allow inheriting classes ot define a non-standard Domain class
    def self.set_domain_class(domain_class)
      error = "No such class #{domain_class}"
      raise ManagerInitializationError.new(error) unless domain_class.is_a? Class
      @domain_class = domain_class
    end

    # Set this manager to use single table inheritance
    def self.single_table_inheritance
      @single_table_inheritance = true
    end

    # Are we using single table inheritance?
    def self.single_table_inheritance?
      @single_table_inheritance == true
    end

    # Override :method_missing so that we can expose certain ActiveRecord methods
    def method_missing(sym, *args, &block)
      return call_active_record(sym, *args, &block) if call_active_record?(sym)
      super(sym, *args, &block)
    end

    # make this reflect the above
    def respond_to?(sym, include_private=false)
      call_active_record?(sym) || super(sym, include_private)
    end

    # methods to persist our domain objects as records.
    def save(obj)
      persist(obj, false)
    end

    def save!(obj)
      persist(obj, true)
    end

    def destroy(obj)
      trash_or_destroy(obj, false)
    end

    def real_destroy!(obj)
      trash_or_destroy(obj, true)
    end

    protected
    # Used by :method_missing
    # Active record methods/method_prefixes that we want to expose
    ACCEPTED_AR_PREFIXES = %w(all find where first second third fourth fifth forty_two last)
    # Any expceptions to the methods that would be matched by the above, that we
    # do not want to expose
    AR_EXCEPTIONS = %w()


    def find_by_sql(sql)
      call_active_record(:find_by_sql, sql)
    end


    # Use active record to make a call to the actual db.
    # Package up what we get back into our domain models and send them back
    def call_active_record(sym, *args, &block)
      response = @record_class.send(sym, *args, &block)

      # got nothing back
      return nil if response.nil?

      # got a few ting back
      if response.is_a?(ActiveRecord::Relation) || response.is_a?(Array)
        return response.map{|obj| build_domain_obj(obj) }
      end

      build_domain_obj(response)

    # wrap up active record errors
    rescue ActiveRecord::RecordNotFound => e
      raise RecordNotFound.new(e)
    end


    # save/update a record
    def persist(obj, bang=false)
      raise InvalidRecordError.new("Cannot save nil") if obj.nil?
      raise InvalidRecordError.new("Mismatched domain class") unless is_valid_class?(obj)

      is_new_record = obj.instance_variable_get(:@new_record)

      if !is_new_record && obj.id != obj.instance_variable_get(:@persisted_id)
        raise InvalidRecordError.new("Manual changing ID not supported")
      end

      is_trashed = obj.instance_variable_get(:@trashed)
      raise InvalidRecordError.new("Cannot saved trash obj") if is_trashed

      run_callbacks :create, obj, if: is_new_record do
        run_callbacks :update, obj, if: !is_new_record do
          run_callbacks :save, obj do
            record = build_record(obj)
            # make rails think this isn't an object we just created.
            # This means it'll happily do an update, instead of an insert.
            # Makes me kinda nervous, as we need to look further at the implications of
            # this. One this that is for certain is that we could optimise our sql
            # queries by setting attrs as dirty or not, as right now it'll think they
            # all are. TS
            record.instance_variable_set(:@new_record, is_new_record)

            save_method = bang ? :save! : :save
            return false unless record.send(save_method)

            # set state on the domain model
            obj.id = record.id
            obj.instance_variable_set(:@persisted_id, record.id)
            obj.instance_variable_set(:@new_record, false)
          end # save
        end # update
      end # create

      true

    # return a Strom Error instead
    rescue ActiveRecord::RecordInvalid => e
      raise InvalidRecordError.new(e)
    rescue ActiveRecord::RecordNotUnique => e
      raise NonUniqueRecordError.new(e)
    end


    def trash_or_destroy(obj, real_delete=false)
      raise InvalidRecordError.new("Cannot destroy nil") if obj.nil?
      raise InvalidRecordError.new("Mismatched domain class") unless is_valid_class?(obj)

      is_new_record = obj.instance_variable_get(:@new_record)
      raise InvalidRecordError.new("Not persisted") if is_new_record

      run_callbacks :destroy, obj do
        if real_delete
          @record_class.destroy obj.instance_variable_get(:@persisted_id)
        else
          record = build_record(obj)
          record.instance_variable_set(:@new_record, false)
          record.trash!
        end

        # TODO: (if is ever an issue), set a different instance variable for real.
        obj.instance_variable_set(:@trashed, true)
      end
    end


    # Create and set state on a domain obj, from a record obj
    def build_domain_obj(record)
      raise Error.new("Cannot build domain obj from #{record.class}") unless record.is_a? ActiveRecord::Base

      # A poor way of removing trashed_at stuff
      attributes = record.attributes.except("trashed_at")

      # instantiate an obj for us to populate
      if self.class.single_table_inheritance?
        obj = record.sti_type.constantize.new 
        # remove sti_type so domain obj doesn't need that attr
        attributes.delete("sti_type")
      else
        obj = @domain_class.new
      end

      # Changed this to use private methods, as it's possible for the public ones
      #  to be intercepted/messed around with, and my current opinion is that the
      #  managers should be returning exactly that which got save, rather than
      #  a potentially messed around with version.
      attributes.each do |k, v|
        obj.send :attribute=, k, v
      end

      is_new_record = record.instance_variable_get(:@new_record)
      obj.instance_variable_set(:@new_record, is_new_record)

      obj.instance_variable_set(:@persisted_id, record.id) unless is_new_record

      obj
    end



    private

    def is_valid_class?(obj)
      obj.is_a?(@domain_class) || self.class.single_table_inheritance?
    end

    # Figure out the name of a class that conforms to our naming standards
    def infer_class(class_suffix)
      manager_class = self.class.name
      inferred_class = manager_class.sub!("Manager", class_suffix)

      error = "Nonstandard class name #{inferred_class} - use #{class_suffix.downcase}_class"
      raise ManagerInitializationError.new(error) if inferred_class.nil?

      begin
        return inferred_class.constantize
      rescue
        raise ManagerInitializationError.new("No such inferred class: #{inferred_class}")
      end
    end


    # for :method_missing and :respond_to? to determine if we've received a
    # method call that we should be dealing with.
    def call_active_record?(sym)
      string = sym.to_s
      return false if AR_EXCEPTIONS.include?(string)

      ACCEPTED_AR_PREFIXES.each do |pre|
        next unless string.starts_with?(pre)
        return @record_class.respond_to?(sym)
      end

      false
    end


    # instatiate or update a record model
    def build_record(obj)
      attribute_hash = {}
      # TODO: implement proper dirty variable tracking in Storm
      # HAAAAAAAAAAAAAAAAAAACK
      # use this to force writing of nils to the db.
      changed_attrs = {}

      attrs_not_to_change = [:id, :updated_at, :created_at]

      obj.attributes.each do |k, v|
        attribute_hash[k] = v
        changed_attrs[k.to_s] = "aflhk4k euhkbdnfgkla" unless attrs_not_to_change.include? k
      end

      record = @record_class.new
      record.attributes = attribute_hash
      record.instance_variable_set :@changed_attributes, changed_attrs
      # save the class, if doing sti
      record.sti_type = obj.class.name if self.class.single_table_inheritance?

      record
    rescue ActiveRecord::UnknownAttributeError => e
      raise Storm::InvalidRecordError.new(e)
    end
  end
end