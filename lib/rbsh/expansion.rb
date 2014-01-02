module Rbsh
  class Expansion
    def initialize(run_ruby_proc = nil)
      @run_ruby_proc = run_ruby_proc
      if ! @run_ruby_proc
        @run_ruby_proc = Proc.new do |code|
          eval code
        end
      end
    end

    def expand_tilde(tokens)
      if tokens.is_a? String
        tokens.gsub('~',ENV["HOME"])
      else
        tokens.collect! do |token|
          token.gsub!('~',ENV["HOME"]) if token.rbsh_quote_type != "'"
          token
        end
      end
    end

    # Perform $ expansion
    def expand_parameters(tokens)
      tokens.collect! do |token|
        token.gsub!(/\$(\w+)/){ENV[$1]} if token.rbsh_quote_type != "'"
        token
      end
    end

    def expand_globs(tokens)
      tokens.flat_map do |token|
        if token.rbsh_quote_type != "'" && (token.index("*") || token.index("?") || token.index("{") || token.index("["))
          Dir.glob(token)
        else
          token
        end
      end
    end

    def expand_ruby(tokens)
      tokens.collect! do |token|
        token = @run_ruby_proc.call(token).to_s if token.rbsh_quote_type == "!"
        token
      end
    end

    def expand(tokens)
      expand_globs(expand_tilde(expand_parameters(expand_ruby(tokens))))
    end

  end
end
