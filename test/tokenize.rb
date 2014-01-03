#!/usr/bin/env ruby 
require 'minitest/unit'
require 'minitest/autorun'
require './lib/rbsh/tokenizer'

class TestTokenizer < MiniTest::Unit::TestCase
  def setup
  end

  def test1
    tokens = Rbsh::Tokenizer.new.tokenize("a test string")
    assert_equal 3, tokens.size
    assert_equal 'a', tokens[0]
    assert_equal 'test', tokens[1]
    assert_equal 'string', tokens[2]
  end

  def test2
    tokens = Rbsh::Tokenizer.new.tokenize("a    test       string        ")
    assert_equal 3, tokens.size
    assert_equal 'a', tokens[0]
    assert_equal 'test', tokens[1]
    assert_equal 'string', tokens[2]
  end

  def test3
    tokens = Rbsh::Tokenizer.new.tokenize("a 'test string'")
    assert_equal 2, tokens.size, "result is #{tokens}"
    assert_equal 'a', tokens[0]
    assert tokens[0].rbsh_quote_type.nil?
    assert_equal 'test string', tokens[1]
    assert_equal "'", tokens[1].rbsh_quote_type

    tokens = Rbsh::Tokenizer.new.tokenize('a "test string"')
    assert_equal 2, tokens.size, "result is #{tokens}"
    assert_equal 'a', tokens[0]
    assert tokens[0].rbsh_quote_type.nil?
    assert_equal 'test string', tokens[1]
    assert_equal '"', tokens[1].rbsh_quote_type
  end

  def test4
    tokens = Rbsh::Tokenizer.new.tokenize("a     'test string'  of power")
    assert_equal 4, tokens.size, "result is #{tokens}"
    assert_equal 'a', tokens[0]
    assert_equal 'test string', tokens[1]
    assert_equal 'of', tokens[2]
    assert_equal 'power', tokens[3]
  end

  def test5
    tokens = Rbsh::Tokenizer.new.tokenize("a 'inner \" quoted' string")
    assert_equal 3, tokens.size, "result is #{tokens}"
    assert_equal 'a', tokens[0]
    assert_equal 'inner " quoted', tokens[1]
    assert_equal 'string', tokens[2]
  end

  def test6
    tokens = Rbsh::Tokenizer.new.tokenize("no 'end terminator")
    assert_equal 2, tokens.size, "result is #{tokens}"
    assert_equal 'no', tokens[0]
    assert_equal 'end terminator', tokens[1]
  end

  def test7
    tokens = Rbsh::Tokenizer.new.tokenize("heres my|pipeline")
    assert_equal 4, tokens.size, "result is #{tokens}"
    assert_equal 'heres', tokens[0]
    assert_equal 'my', tokens[1]
    assert_equal '|', tokens[2]
    assert_equal 'pipeline', tokens[3]
  end

  def test8
    tokens = Rbsh::Tokenizer.new.tokenize("heres my | pipeline")
    assert_equal 4, tokens.size, "result is #{tokens}"
    assert_equal 'heres', tokens[0]
    assert_equal 'my', tokens[1]
    assert_equal '|', tokens[2]
    assert_equal 'pipeline', tokens[3]
  end

  def test9
    tokens = Rbsh::Tokenizer.new.tokenize("'test my' quote")
    assert_equal 2, tokens.size, "result is #{tokens}"
    assert_equal 'test my', tokens[0]
    assert_equal 'quote', tokens[1]
  end

  def test10
    tokens = Rbsh::Tokenizer.new.tokenize("!my ruby code! and stuff")
    assert_equal 3, tokens.size, "result is #{tokens}"
    assert_equal 'my ruby code', tokens[0]
    assert_equal 'and', tokens[1]
    assert_equal 'stuff', tokens[2]
  end

  def test11
    tokens = Rbsh::Tokenizer.new.tokenize("! my ruby code ! stuff")
    assert_equal 2, tokens.size, "result is #{tokens}"
    assert_equal ' my ruby code ', tokens[0]
    assert_equal 'stuff', tokens[1]
  end

  def testEscape1
    tokens = Rbsh::Tokenizer.new.tokenize("my \\'simple escape\\'")
    assert_equal 3, tokens.size, "result is #{tokens}"
    assert_equal 'my', tokens[0]
    assert_equal "'simple", tokens[1]
    assert_equal "escape'", tokens[2]
  end

  def testEscape2
    tokens = Rbsh::Tokenizer.new.tokenize("my \\!simple escape\\! here")
    assert_equal 4, tokens.size, "result is #{tokens}"
    assert_equal 'my', tokens[0]
    assert_equal "!simple", tokens[1]
    assert_equal "escape!", tokens[2]
    assert_equal "here", tokens[3]
  end

  def testEscape3
    tokens = Rbsh::Tokenizer.new.tokenize("my !internal \\! escape!")
    assert_equal 2, tokens.size, "result is #{tokens}"
    assert_equal 'my', tokens[0]
    assert_equal "internal ! escape", tokens[1]
  end

  def testSplit1
    toker = Rbsh::Tokenizer.new 
    tokens = Rbsh::Tokenizer.split(toker.tokenize("heres my | pipeline | of pain"), "|")
    
    assert_equal 3, tokens.size, "result is #{tokens}"
    assert_equal ['heres','my'], tokens[0]
    assert_equal ['pipeline'], tokens[1]
    assert_equal ['of','pain'], tokens[2]
  end

  def testSplit2
    toker = Rbsh::Tokenizer.new 
    tokens = Rbsh::Tokenizer.split(toker.tokenize("heres my | pipeline | "), "|")
    
    assert_equal 3, tokens.size, "result is #{tokens}"
    assert_equal ['heres','my'], tokens[0]
    assert_equal ['pipeline'], tokens[1]
    assert_equal [], tokens[2]
  end

  def testSplit3
    toker = Rbsh::Tokenizer.new 
    tokens = Rbsh::Tokenizer.split(toker.tokenize("heres my cmd"), "|")
    
    assert_equal 1, tokens.size, "result is #{tokens}"
    assert_equal ['heres','my', 'cmd'], tokens[0]
  end
end
