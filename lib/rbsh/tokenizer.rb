class String
  # If this string is a token returned from Rbsh::Tokenizer::tokenize and this
  # token was part of a quoted string, this value is set to the quote character 
  # ' or "
  def rbsh_quote_type
    (defined? @rbsh_quote_type) ? @rbsh_quote_type : nil
  end

  def rbsh_quote_type=(v)
    @rbsh_quote_type = v
  end
end

module Rbsh
  class Tokenizer
    def initialize
      @quote_chars = ['"',"'","!"]
      # Characters that are tokens by themselves
      @token_chars = ['|','>','<', '&']
    end

    def tokenize(str)
      tokens = str.each_char.to_a.reduce([]) do |memo, char|
        if memo.length > 0
          quote = memo.last[0] 
          if @quote_chars.index(quote)
            # We are in a quote.
            if quote == char
              memo.last[0] = ""
              memo.last.rbsh_quote_type = quote
              memo.push ""
            else
              memo.last.concat char
            end
          else
            if @quote_chars.index(quote)
              if memo.last.length == 0
                memo.last.concat char
              else
                memo.push char
              end
            elsif @token_chars.index(char)
              if memo.last.length == 0
                memo.last.concat char
              else
                memo.push char
              end
              memo.push ""
            elsif char == ' '
              memo.push "" if memo.last.length > 0
            else 
              memo.last.concat char
            end
          end
        else
          memo.push char
        end
        memo
      end

      tokens.pop if tokens.last && tokens.last.size == 0
      tokens.last[0] = "" if (@quote_chars.index(tokens.last[0])) && ! (@quote_chars.index(tokens.last[-1]))
      tokens
    end

    # Given an array of tokens (as generated by tokenize) split the array on the given element.
    # For example, if the array is ['a','b','|','c'] and the split is '|', then the result is
    # [['a','b']['c']]
    def self.split(tokens, on)
      tokens.reduce([]) do |memo, e|
        if e == on
          memo.push []
        else
          if memo.last
            memo.last.push e
          else
            memo.push [e]
          end
        end
        memo
      end
    end
  end
end

