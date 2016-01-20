require 'spec_helper'
require 'active_record'
require 'sqlite3'

describe Storm::BaseModel do

  before :each do 
    class UserManager < Storm::BaseManager; end
    class DogManager < Storm::BaseManager; end
    class User < Storm::BaseModel
      attributes :id, :thing, :other_thing
    end

    @user = User.new
  end

  after :all do
    Object.send(:remove_const, :UserManager)
    Object.send(:remove_const, :User)
    Object.send(:remove_const, :DogManager)
    Object.send(:remove_const, :Child)
  end

  context 'defining attributes' do
    it 'should have a getter defined' do
      expect(@user).to respond_to(:thing)
      expect(@user).to respond_to(:other_thing)
    end

    it 'should have a setter defined' do
      expect(@user).to respond_to(:thing=)
      expect(@user).to respond_to(:other_thing=)
    end

    it 'should not something not defined defined' do
      expect{@user.other_other_thing}.to raise_error(NoMethodError)
    end

    context 'errors' do
      it 'should not like setting no attrs' do
        expect{ class Ting < Storm::BaseModel; attributes; end }.to raise_error(ArgumentError)
      end
    end
  end

  context 'inferred manager class' do
    it 'should correctly infer the manager calss' do
      expect(User.manager).to eq(UserManager)
    end
  end

  context 'overiding inferred manager class' do
      it 'should set the record class' do
        User.set_manager_class DogManager
        expect(User.manager).to eq(DogManager)
      end

      it 'should raise if arg is not a class' do
        expect{ User.set_manager_class "not a class" }.to raise_error(Storm::ManagerInitializationError)
      end
  end

  context 'getters and setter work' do
    it 'should allow me to get what I set' do
      thing = "hi"
      @user.thing = thing
      expect(@user.thing).to eq(thing)
    end

    it 'should return nil if an attr had something set' do
      expect(@user.thing).to be_nil
    end
  end

  context 'internal state' do
    it 'gets set up correctly' do
      expect(@user.instance_variable_get(:@new_record)).to eq(true)
      expect(@user.instance_variable_get(:@attributes)).to eq({})
    end
  end

  context 'instantiation' do
    it 'should not allow instatiation of BaseModel directly' do
      expect{ Storm::BaseModel.new }.to raise_error(Storm::Error)
    end

    it 'allows you to set attrs with a hash' do
      @user = User.new({ thing: "hi" })
      expect(@user.thing).to eq("hi")
      expect(@user.other_thing).to be_nil
    end

    it 'does not needs args' do
      expect{ User.new }.not_to raise_error
    end

    it 'is happy with an empty hash' do
      expect{ User.new({}) }.not_to raise_error
    end
  end

  describe 'becomes' do
    class Child < User; end

    it 'sets @new_record' do
      @user.instance_variable_set(:@new_record, false)
      child = @user.becomes(Child)
      expect(child.instance_variable_get(:@new_record)).to eq false
    end
    it 'sets @persisted_id' do
      @user.instance_variable_set(:@persisted_id, 123)
      child = @user.becomes(Child)
      expect(child.instance_variable_get(:@persisted_id)).to eq 123
    end
    it 'sets @trashed' do
      @user.instance_variable_set(:@trashed, true)
      child = @user.becomes(Child)
      expect(child.instance_variable_get(:@trashed)).to eq true
    end

    it 'creates a new obj' do
      expect(Child).to receive(:new).with(@user.attributes).and_call_original
      child = @user.becomes(Child)
      expect(child.class).to eq(Child)
    end
  end
end