#!/usr/bin/env ruby 
require 'minitest/unit'
require 'minitest/autorun'
require 'lib/rbsh/tokenizer'

class TestTokenizer < MiniTest::Unit::TestCase
  def setup
  end

  def test1
    tokens = Rbsh::Tokenizer.tokenize("a test string")
    assert_equal 3, tokens.size
    assert_equal 'a', tokens[0]
    assert_equal 'test', tokens[1]
    assert_equal 'string', tokens[2]
  end

  def test2
    tokens = Rbsh::Tokenizer.tokenize("a    test       string        ")
    assert_equal 3, tokens.size
    assert_equal 'a', tokens[0]
    assert_equal 'test', tokens[1]
    assert_equal 'string', tokens[2]
  end

  def test3
    tokens = Rbsh::Tokenizer.tokenize("a 'test string'")
    assert_equal 2, tokens.size, "result is #{tokens}"
    assert_equal 'a', tokens[0]
    assert_equal 'test string', tokens[1]
  end

  def test4
    tokens = Rbsh::Tokenizer.tokenize("a     'test string'  of power")
    assert_equal 4, tokens.size, "result is #{tokens}"
    assert_equal 'a', tokens[0]
    assert_equal 'test string', tokens[1]
    assert_equal 'of', tokens[2]
    assert_equal 'power', tokens[3]
  end

  def test5
    tokens = Rbsh::Tokenizer.tokenize("a 'inner \" quoted' string")
    assert_equal 3, tokens.size, "result is #{tokens}"
    assert_equal 'a', tokens[0]
    assert_equal 'inner " quoted', tokens[1]
    assert_equal 'string', tokens[2]
  end

  def test6
    tokens = Rbsh::Tokenizer.tokenize("no 'end terminator")
    assert_equal 2, tokens.size, "result is #{tokens}"
    assert_equal 'no', tokens[0]
    assert_equal 'end terminator', tokens[1]
  end
end
