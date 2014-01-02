#!/usr/bin/env ruby 
require 'minitest/unit'
require 'minitest/autorun'
require './lib/rbsh/tokenizer'
require './lib/rbsh/expansion'

include Rbsh

class TestExpansion < MiniTest::Unit::TestCase

  def test_tilde
    tokens = Tokenizer.new.tokenize("~")
    exp = Expansion.new
    assert_equal [ENV['HOME']], exp.expand_tilde(tokens)

    tokens = Tokenizer.new.tokenize("'~'")
    exp = Expansion.new
    assert_equal ['~'], exp.expand_tilde(tokens)

    tokens = Tokenizer.new.tokenize('"~"')
    exp = Expansion.new
    assert_equal [ENV['HOME']], exp.expand_tilde(tokens)

    tokens = Tokenizer.new.tokenize('"  ~  "')
    exp = Expansion.new
    assert_equal ["  #{ENV['HOME']}  "], exp.expand_tilde(tokens)
  end

  def test_param
    ENV['RBSH_TEST'] = "bar"
    tokens = Tokenizer.new.tokenize("$RBSH_TEST")
    exp = Expansion.new
    assert_equal ['bar'], exp.expand_parameters(tokens)

    tokens = Tokenizer.new.tokenize("'$RBSH_TEST'")
    exp = Expansion.new
    assert_equal ['$RBSH_TEST'], exp.expand_parameters(tokens)

    tokens = Tokenizer.new.tokenize("$RBSH_TEST $RBSH_TEST")
    exp = Expansion.new
    assert_equal ['bar','bar'], exp.expand_parameters(tokens)
  end

  def test_ruby
    tokens = Tokenizer.new.tokenize("!14+5!")
    exp = Expansion.new
    assert_equal ['19'], exp.expand_ruby(tokens)
  end

  def test_glob
    tokens = Tokenizer.new.tokenize("te?t/expans*rb")
    exp = Expansion.new
    assert_equal ['test/expansion.rb'], exp.expand_globs(tokens)

    tokens = Tokenizer.new.tokenize("te?t/*rb")
    exp = Expansion.new
    expanded = exp.expand_globs(tokens)
    assert expanded.size > 1
    expanded.each do |e|
      assert e.is_a?(String)
    end

  end
end
