require 'spec_helper'

require 'active_record'
require 'sqlite3'

describe Storm::BaseManager do

  # setup some active record stuff, so we can check our integration works
  before :all do
    ActiveRecord::Base.establish_connection(
      adapter: 'sqlite3',
      database: 'storm_test.sqlite3'
    )

    m = ActiveRecord::Migration
    m.verbose = false  
    m.create_table :user_records do |t| 
      t.integer :number
      t.string :thing
      t.string :sti_type
    end
  end

  after :all do
    m = ActiveRecord::Migration
    m.verbose = false
    m.drop_table :user_records

    # incase we want to redefine these thing else where
    Object.send(:remove_const, :UserRecord)
    Object.send(:remove_const, :PersonRecord)
  end

  class User < Storm::BaseModel
    attributes :id, :number, :thing
  end
  class Person < Storm::BaseModel
    attributes :id
  end
  class UserRecord < ActiveRecord::Base
    I18n.enforce_available_locales = false # remove a warning we don't care about
    validates :number, numericality: true, allow_nil: true
  end
  class PersonRecord < ActiveRecord::Base; end 
  class UserManager < Storm::BaseManager
    # methods use to expose internals, so we can check it's working
    def get_record_class; @record_class; end
    def get_domain_class; @domain_class; end
  end
  class DogManager < Storm::BaseManager; end  
  class DogCat < Storm::BaseManager
    def get_record_class; @record_class; end
    def get_domain_class; @domain_class; end
  end

  context 'abstract class' do
    it 'should not allow instatiation of BaseManager' do
      expect{ Storm::BaseManager.new }.to raise_error(Storm::Error)
    end
  end

  context 'inferred classes' do
    describe 'record_class' do
      it 'should correctly infer the record class' do
        expect(UserManager.new.get_record_class).to eq(UserRecord)
      end
    end

    describe 'domain_class' do
      it 'should correctly infer the domain class' do
        expect(UserManager.new.get_domain_class).to eq(User)
      end
    end

    describe 'errors' do
      it 'should raise if the inferred class does not exist' do
        expect{ DogManager.new }.to raise_error(Storm::ManagerInitializationError)
      end

      it 'should raise if strange manger class name (and classes not overridden)' do
        expect{ DogCat.new }.to raise_error(Storm::ManagerInitializationError)
      end
    end
  end

  context 'overriding inferred classes' do
    # reset the stuff we change in here...
    # TODO: move class definitions inside contexts to ensure non-interdependence
    #  of tests
    after :each do
      UserManager.instance_variable_set(:@record_class, nil)
      UserManager.instance_variable_set(:@domain_class, nil)
      DogCat.instance_variable_set(:@record_class, nil)
      DogCat.instance_variable_set(:@domain_class, nil)
    end

    describe 'record_class' do
      it 'should set the record class' do
        UserManager.set_record_class PersonRecord
        expect(UserManager.new.get_record_class).to eq(PersonRecord)
      end

      it 'should raise if arg is not a class' do
        expect{ UserManager.set_record_class "not a class" }.to raise_error(Storm::ManagerInitializationError)
      end
    end

    describe 'domain_class' do
      it 'should set the domain class' do
        UserManager.set_domain_class Person
        expect(UserManager.new.get_domain_class).to eq(Person)
      end

      it 'should raise if arg is not a class' do
        expect{ UserManager.set_domain_class "not a class" }.to raise_error(Storm::ManagerInitializationError)
      end
    end

    context 'nonconformist manager names' do
      it 'should set the record class for strange-named manger clases' do
        DogCat.set_record_class PersonRecord
        DogCat.set_domain_class Person
        expect(DogCat.new.get_domain_class).to eq(Person)
        expect(DogCat.new.get_record_class).to eq(PersonRecord)
      end
    end
  end

  context 'single table inheritance' do
    # switch off STI for other tests.
    after :each do
      UserManager.instance_variable_set(:@single_table_inheritance, false)
    end

    it 'single_table_inheritance method sets sti to true' do
      expect(UserManager.single_table_inheritance?).to eq(false)
      UserManager.single_table_inheritance
      expect(UserManager.single_table_inheritance?).to eq(true)
    end

    context 'enabled' do
      before :each do
        UserManager.single_table_inheritance
        @um = UserManager.new
      end
      it 'saves the domain obj class to the record' do
        p = Person.new
        ur = UserRecord.new
        expect(UserRecord).to receive(:new).and_return(ur)
        @um.save! p

        expect(ur.sti_type).to eq('Person')
      end
      it 'instantiates the correct kind of class' do
        ur = UserRecord.create!(id: 999, sti_type: 'Person')
        p = @um.find(999)
        expect(p.class).to eq(Person)
      end
      it 'does not set sti_type on the domain class' do
        ur = UserRecord.create!(id: 998, sti_type: 'Person')
        p = @um.find(998)
        expect(p.attributes.keys).not_to include(:sti_type)
      end
    end
  end

  context 'exposing active record methods through method_missing/repond_to?' do
    before :all do
      UserManager.set_record_class UserRecord
      UserManager.set_domain_class User
    end

    it 'should error on thing we do not want to expose' do
      manager = UserManager.new
      %w(find_asfsadafs create update_attribute askdfjhsakldf).each do |m|
        expect{manager.send(m)}.to raise_error(NoMethodError)
      end
    end

    it 'should :call_active_record for find' do
      manager = UserManager.new
      expect(manager).to receive(:call_active_record).with(:find, 1)
      manager.find(1)
    end

    it 'should :call_active_record for find_by_sql' do
      sql = "tims sweet sql"
      manager = UserManager.new
      expect(manager).to receive(:call_active_record).with(:find_by_sql, sql)
      manager.find_by_sql(sql)
    end

    it 'should :call_active_record for where' do
      manager = UserManager.new
      expect(manager).to receive(:call_active_record).with(:where, { thing: "thing"})
      manager.where(thing: "thing")
    end

    it 'should :call_active_record for find' do
      manager = UserManager.new
      expect(manager).to receive(:call_active_record).with(:first)
      manager.first
    end
  end

  context 'loading objects' do
    context 'calling ActiveRecord methods on Record objects' do
      before :each do
        (1..3).each{ UserRecord.create!(number: 1) }
      end

      after :each do
        UserRecord.delete_all
      end

      it 'returns nil if AR gives nil back' do
        expect(UserManager.new.forty_two).to eq(nil)
      end

      it 'returns a domain model if we get one thing back' do
        expect(UserManager.new.first.class).to eq(User)
      end

      it 'returns an aray of domain models if we get 2+ things back' do
        array = UserManager.new.where(number: 1)
        expect(array.class).to eq(Array)
        expect(array.size).to eq(3)
        expect(array.first.class).to eq(User)
      end

      it 'raises our error if it cannot find a record' do
        expect{ UserManager.new.find(1000) }.to raise_error(Storm::RecordNotFound)
      end
    end


    context 'building domain objects' do
      before :each do
        @ur = UserRecord.create!({ thing: "hi" })
      end

      after :each do
        UserRecord.delete_all
      end

      it 'sets attrs correctly' do
        @user = UserManager.new.send(:build_domain_obj, @ur)
        expect(@user.thing).to eq("hi")
        expect(@user.number).to be_nil        
      end

      it 'sets @new_record=false on the new obj if ar obj saved' do
        @user = UserManager.new.send(:build_domain_obj, @ur)
        expect(@user.instance_variable_get(:@new_record)).to eq(false)
      end

      it 'sets @new_record=true on the new obj if ar obj not saved' do
        @user = UserManager.new.send(:build_domain_obj, UserRecord.new)
        expect(@user.instance_variable_get(:@new_record)).to eq(true)
      end

      it 'sets @persisted_id if ar obj saved' do
        @user = UserManager.new.send(:build_domain_obj, @ur)
        expect(@user.instance_variable_get(:@persisted_id)).to eq(@ur.id)
      end

      it 'does not set @persisted_id ar obj saved' do
        @user = UserManager.new.send(:build_domain_obj, UserRecord.new)
        expect(@user.instance_variable_get(:@persisted_id)).to be_nil
      end
    end
  end


  context 'persisting objects' do
    before :each do
      @u = User.new
      @u.number = 10
    end

    after :each do
      UserRecord.delete_all
    end

    it 'should save a record' do
      UserManager.new.save(@u)
      expect(UserRecord.count).to eq(1)
    end

    it 'should put the id in the domain obj' do
      UserManager.new.save(@u)
      expect(@u.id).not_to be_nil
    end

    it 'should set @new_record=false on the domain obj' do
      UserManager.new.save(@u)
      expect(@u.instance_variable_get(:@new_record)).to eq(false)
    end

    it 'should not change the id if a model is resaved' do
      UserManager.new.save(@u)
      id = @u.id
      UserManager.new.save(@u)
      expect(id).to eq(@u.id)
    end

    it 'should correctly record attrs to nil ' do
      um = UserManager.new
      um.save @u
      new_u = um.find @u.id 
      new_u.number = nil
      um.save new_u
      another_new_u = um.find(@u.id)
      expect(another_new_u.number).to be_nil
    end

    context 'invalid records' do
      it 'raises if you try and save nil' do
        expect{ UserManager.new.save(nil) }.to raise_error(Storm::InvalidRecordError)
      end

      it 'raises if you try and save with the wrong manager' do
        expect{ UserManager.new.save(Person.new) }.to raise_error(Storm::InvalidRecordError)
      end

      it 'raises if you try and save a trashed object' do
        @u.instance_variable_set(:@trashed, true)
        expect{ UserManager.new.save(@u) }.to raise_error(Storm::InvalidRecordError)
      end

      it 'returns false if using save and record invalid' do
        @u.number = 'a'
        expect(UserManager.new.save(@u)).to eq(false)
      end

      it 'does not set instance vars on domain obj if saving fails' do
        @u.number = 'a'
        UserManager.new.save(@u)
        expect(@u.instance_variable_get(:@new_record)).to eq(true)
        expect(@u.instance_variable_get(:@persisted_id)).to be_nil
        expect(@u.id).to be_nil
      end

      it 'raises if using save! and record invalid' do
        @u.number = 'a'
        expect{ UserManager.new.save!(@u) }.to raise_error(Storm::InvalidRecordError)
      end

      it 'raises if you mess about with an ID in a persisted domain obj' do
        UserManager.new.save(@u)
        @u.id = 928374
        expect{ UserManager.new.save!(@u) }.to raise_error(Storm::InvalidRecordError)
      end
    end

    context 'deleting objects' do
      before :each do
        @u = User.new
        @um = UserManager.new
      end
      context 'when invalid' do
        it 'should error if you try and delete nil' do
          expect{ @um.destroy(nil) }.to raise_error(Storm::InvalidRecordError)
        end
        it 'should error if you try and delete with the wrong manager' do
          expect{ @um.destroy(Person.new) }.to raise_error(Storm::InvalidRecordError)
        end
        it 'should error if the obj is not persisted' do
          expect{ @um.destroy(@u) }.to raise_error(Storm::InvalidRecordError)
        end
      end

      context 'with soft delete' do
        before :each do
          @u.instance_variable_set(:@new_record, false)
        end
        it 'should build and trash! a record' do
          fake_record = double()
          expect(@um).to receive(:build_record).with(@u).and_return(fake_record)
          expect(fake_record).to receive(:trash!)
          @um.destroy(@u)
        end
        it 'should set the obj as trashed' do
          fake_record = double(trash!: true)
          allow(@um).to receive(:build_record).with(@u).and_return(fake_record)
          expect(@u).to receive(:instance_variable_set).with(:@trashed, true)
          @um.destroy(@u)
        end
      end

      context 'with real delete' do
        before :each do
          @u.instance_variable_set(:@new_record, false)
          @id = 123
          @u.instance_variable_set(:@persisted_id, @id)
        end

        it 'should directly destroy the record' do
          expect(UserRecord).to receive(:destroy).with(@id)
          @um.real_destroy!(@u)
        end
        it 'should set the obj as trashed' do
          allow(UserRecord).to receive(:destroy).with(@id)
          expect(@u).to receive(:instance_variable_set).with(:@trashed, true)
          @um.real_destroy!(@u)
        end
      end
    end
  end
end