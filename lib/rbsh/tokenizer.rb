module Rbsh
  class Tokenizer
    def self.tokenize(str)
      tokens = str.each_char.to_a.reduce([]) do |memo, char|
#puts "char = #{char}"
        if memo.length > 0
          quote = memo.last[0] 
          if quote == '"' || quote == "'"
            if quote == char
              memo.last[0] = ""
              memo.push ""
            else
              memo.last.concat char
            end
          else
            if char == '"' || char == "'"
              if memo.last.length == 0
                memo.last.concat char
              else
                memo.push char
              end
            elsif char == ' '
              memo.push "" if memo.last.length > 0
            else 
              memo.last.concat char
            end
          end
        else
          memo.push char
        end
#puts "memo = #{memo}"
        memo
      end

      tokens.pop if tokens.last && tokens.last.size == 0
      tokens.last[0] = "" if (tokens.last[0] == '"' || tokens.last[0] == "'") && ! (tokens.last[-1] == '"' || tokens.last[-1] == "'")
      tokens
    end
  end
end

