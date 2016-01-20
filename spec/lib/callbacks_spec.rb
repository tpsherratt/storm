require 'spec_helper'

describe Storm::Callbacks do

  after :all do
    Object.send(:remove_const, :TestOne)
    Object.send(:remove_const, :TestTwo)
    Object.send(:remove_const, :TestThree)
    Object.send(:remove_const, :TestBase)
    Object.send(:remove_const, :TestChildOne)
    Object.send(:remove_const, :TestChildTwo)
  end

  class TestOne
    include Storm::Callbacks
    define_callbacks :save
  end

  class TestTwo
    include Storm::Callbacks
    define_callbacks :save
    before_save :before
    after_save :after

    def before(x); end
    def after(x); end

    def save
      run_callbacks :save, :hi do
      end
    end
  end

  class TestThree
    include Storm::Callbacks
    define_callbacks :save

    def save
      run_callbacks :save, :hi do
      end
    end
  end

  it 'defines before_xxx/after_xxx methods for defined callbacks' do
    expect(TestOne).to respond_to(:before_save)
    expect(TestOne).to respond_to(:after_save)
  end

  it 'runs callbacks and provides args' do
    tt = TestTwo.new
    expect(tt).to receive(:before).with(:hi)
    expect(tt).to receive(:after).with(:hi)
    tt.save
  end

  it 'does not mind if callbacks are not set' do
    tt = TestThree.new
    expect{ tt.save }.not_to raise_error
  end

  context 'inheritance' do
    class TestBase
      include Storm::Callbacks
      define_callbacks :save

      def save
        run_callbacks :save, :hi do
        end
      end
    end

    class TestChildOne < TestBase
      before_save :one
      def one(x); end
      def two(x); end
    end

    class TestChildTwo < TestBase
      before_save :two
      def one(x); end
      def two(x); end
    end

    it 'keeps subclass callbacks separate' do
      to = TestChildOne.new
      tt = TestChildTwo.new

      # just its callback for child one
      expect(to).to receive(:one)
      expect(to).not_to receive(:two)

      # nothing for child two
      expect(tt).not_to receive(:one)
      expect(tt).not_to receive(:two)

      to.save
    end
  end
end