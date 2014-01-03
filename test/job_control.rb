#!/usr/bin/env ruby 
require 'minitest/unit'
require 'minitest/autorun'
require './lib/rbsh/tokenizer'
require './lib/rbsh/job_control'

include Rbsh

class TestTokenizer < MiniTest::Unit::TestCase
  def setup
  end

  def test1
    p = Pipeline.new("ls")
    assert_equal 1, p.cmd_lines.size
    assert_equal ['ls'], p.cmd_lines[0].argv
  end

  def test2
    p = Pipeline.new("ls -l")
    assert_equal 1, p.cmd_lines.size
    assert_equal ['ls','-l'], p.cmd_lines[0].argv
  end

  def test3
    p = Pipeline.new("ls -l dir1 f/* 'other dir/*'")
    assert_equal 1, p.cmd_lines.size
    assert_equal ['ls','-l','dir1','f/*','other dir/*'], p.cmd_lines[0].argv
  end

  def test4
    p = Pipeline.new("cat < file1 > file2")
    assert_equal 1, p.cmd_lines.size
    assert_equal ['cat'], p.cmd_lines[0].argv
    assert_equal 'file1', p.cmd_lines[0].stdin_redirect
    assert_equal 'file2', p.cmd_lines[0].stdout_redirect
  end

  def test5
    p = Pipeline.new("cat 2> file2")
    assert_equal 1, p.cmd_lines.size
    assert_equal ['cat'], p.cmd_lines[0].argv
    assert_equal 'file2', p.cmd_lines[0].stderr_redirect
  end

  def test6
    p = Pipeline.new("cat 2 > file2")
    assert_equal 1, p.cmd_lines.size
    assert_equal ['cat'], p.cmd_lines[0].argv
    assert_equal 'file2', p.cmd_lines[0].stderr_redirect
  end

  def test7
    p = Pipeline.new("cat <file1 >file2")
    assert_equal 1, p.cmd_lines.size
    assert_equal ['cat'], p.cmd_lines[0].argv
    assert_equal 'file1', p.cmd_lines[0].stdin_redirect
    assert_equal 'file2', p.cmd_lines[0].stdout_redirect
  end

  def test8
    p = Pipeline.new("cat -l < 'my file1' 2>'the file2'")
    assert_equal 1, p.cmd_lines.size
    assert_equal ['cat','-l'], p.cmd_lines[0].argv
    assert_equal 'my file1', p.cmd_lines[0].stdin_redirect
    assert_equal 'the file2', p.cmd_lines[0].stderr_redirect
  end

  def test9
    p = Pipeline.new("cat < 'my file1' | less -R | blarg")
    assert_equal 3, p.cmd_lines.size
    assert_equal ['cat'], p.cmd_lines[0].argv
    assert_equal 'my file1', p.cmd_lines[0].stdin_redirect

    assert_equal ['less','-R'], p.cmd_lines[1].argv

    assert_equal ['blarg'], p.cmd_lines[2].argv
  end

  def test10
    # Can't redirect stdout to file and to a pipe
    assert_raises(RuntimeError){ Pipeline.new("cat > file | less") }
  end

  def test11
    # Can't redirect stdin from a file and from a pipe
    assert_raises(RuntimeError){ Pipeline.new("cat file | cat < file") }
  end

  def test12
    # Can't redirect to two files
    assert_raises(RuntimeError){ Pipeline.new("cat > file1 file2") }
  end

  def test13
    p = Pipeline.new("ls 456")
    assert_equal 1, p.cmd_lines.size, "number of tokens in command 'ls 456'"
    assert_equal ['ls','456'], p.cmd_lines[0].argv
  end

  def test14
    p = Pipeline.new("ls 456 123")
    assert_equal 1, p.cmd_lines.size, "number of tokens in command 'ls 456'"
    assert_equal ['ls','456','123'], p.cmd_lines[0].argv
  end

  def test15
    p = Pipeline.new("ls 456 abc 123")
    assert_equal 1, p.cmd_lines.size, "number of tokens in command 'ls 456'"
    assert_equal ['ls','456','abc','123'], p.cmd_lines[0].argv
  end

  def test16
    p = Pipeline.new("ls 456 abc 123 def")
    assert_equal 1, p.cmd_lines.size, "number of tokens in command 'ls 456'"
    assert_equal ['ls','456','abc','123', 'def'], p.cmd_lines[0].argv
  end

end

