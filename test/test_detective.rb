require 'helper'

class BadrIT
	def self.hello
		puts "hello BadrIT"
	end
end

class TestDetective < Test::Unit::TestCase
  def test_simple_method
    
    source = Detective.view_source('BadrIT.hello')
    assert_equal 'def self.hello puts "hello BadrIT" end', source.sub(/\s+/, ' ')
  end
end
