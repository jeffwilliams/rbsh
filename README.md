Rbsh - Simple Ruby Shell
========================

A simple Linux shell written in Ruby. 

Features
--------

  * Job Control
  * Readline and completion
  * Directory history. Navigate using ALT-LEFT, ALT-RIGHT, and ALT-UP.
  * Ruby expression substitution

How To use Ruby Substitution
----------------------------

As part of a command line, you can substitute the result of evaluating ruby code. Just place the code inside bangs:
    
    $ echo The time is !Time.new!
    The time is 2014-01-03 16:10:42 -0500

As a convenience, if you want the entire line to be interpreted as ruby begin the line with a bang, and don't terminate the bang:

    $ !puts "Addition is fun: #{4+5}"
    Addition is fun: 9
    nil

You can also pipe into ruby code. The ruby code's $stdin is hooked up to the previous command:

    $ ls | !$stdin.each_line{ |l| puts "Good ol' " + l.chomp + "'s" }!

    ls | !$stdin.each_line{ |l| puts l.chomp + "'s" }!
    Good ol' bin's
    Good ol' lib's
    Good ol' LICENSE's
    Good ol' old's
    Good ol' Rakefile's
    Good ol' rbsh-0.0.1.gem's
    Good ol' rbsh.gemspec's
    Good ol' README.md's
    Good ol' test's
    Good ol' TODO's

    $ ls | !$stdin.each_line{ |l| puts l if File.directory?(l.chomp) }! | wc
    4       4      17


