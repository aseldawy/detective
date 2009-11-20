require 'helper'

class BadrIT; end

class TestDetective < Test::Unit::TestCase
  def test_simple_method
  	BadrIT.class_eval do 
  		def self.hello
				puts "hello BadrIT"
			end
		end
  
    source = Detective.view_source('BadrIT.hello')
    assert_equal 'def self.hello puts "hello BadrIT" end', source.gsub(/\s+/, ' ').strip
  end
  
  def test_overrided_method
  	def BadrIT.abc
  		puts "BadrIT rulez!!"
  	end
  	
    source = Detective.view_source('BadrIT.abc')
  	assert_equal 'def BadrIT.abc puts "BadrIT rulez!!" end', source.gsub(/\s+/, ' ').strip

  	def BadrIT.abc
  		puts "BadrIT is the best!!"
  	end
  	
    source = Detective.view_source('BadrIT.abc')
  	assert_equal 'def BadrIT.abc puts "BadrIT is the best!!" end', source.gsub(/\s+/, ' ').strip
  end
  
	def test_instance_method
		BadrIT.class_eval do
			def test
				puts "testing"
			end
		end
		
		source = Detective.view_source('BadrIT#test')
		assert_equal 'def test puts "testing" end', source.gsub(/\s+/, ' ').strip
	end
  
  def test_method_with_args
    BadrIT.class_eval do
      def test(arg0)
        puts "nothing here"
      end
    end
    
    source = Detective.view_source('BadrIT#test')
    assert_equal 'def test(arg0) puts "nothing here" end', source.gsub(/\s+/, ' ').strip
  end
  
  def test_method_with_optional_args
    BadrIT.class_eval do
      def test1(arg0, arg1="test", arg2="habal")
        puts "nothing here"
      end
    end
    
    source = Detective.view_source('BadrIT#test1')
    assert_equal 'def test1(arg0, arg1="test", arg2="habal") puts "nothing here" end', source.gsub(/\s+/, ' ').strip
  end
  
  def test_method_with_variable_args
    BadrIT.class_eval do
      def test2(arg0, arg1="test", *args)
        puts "nothing here"
      end
    end
    
    source = Detective.view_source('BadrIT#test2')
    assert_equal 'def test2(arg0, arg1="test", *args) puts "nothing here" end', source.gsub(/\s+/, ' ').strip
  end

  def test_native_method
    source = Detective.view_source('String#length')
    assert_equal 'native method', source.gsub(/\s+/, ' ').strip
  end

  def test_native_method_with_args
    source = Detective.view_source('String#sub')
    assert_equal 'native method', source.gsub(/\s+/, ' ').strip
  end

  def test_undefined_method
    assert_raises RuntimeError do
      Detective.view_source('String#adfasdf')
    end
  end

  def test_using_threads
    fork_supported = Detective.const_get(:ForkSupported)
    Detective.const_set(:ForkSupported, false)
    BadrIT.class_eval do 
      def self.noway
        puts "Go away"
      end
    end
  
    source = Detective.view_source('BadrIT.noway')
    assert_equal 'def self.noway puts "Go away" end', source.gsub(/\s+/, ' ').strip

    Detective.const_set(:ForkSupported, fork_supported)
  end

  def test_with_required_initializers
    BadrIT.class_eval do 
      def initialize(arg0, arg1, arg2)
      end

      def some_method
        puts "me myself"
      end
    end
  
    source = Detective.view_source('BadrIT#some_method')
    assert_equal 'def some_method puts "me myself" end', source.gsub(/\s+/, ' ').strip
  end

  def test_method_with_eval
    eval %Q{
    BadrIT.class_eval do 
      def self.yaya
        puts "yaya BadrIT"
      end
    end
    }
    
    source = Detective.view_source('BadrIT.yaya')
    assert_equal 'Cannot find source code', source.gsub(/\s+/, ' ').strip
  end
  
  def test_invalid_method_name
    assert_raises RuntimeError do
      Detective.view_source('BadrIT')
    end
  end

end
