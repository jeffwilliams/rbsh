# http://www.frexx.de/xterm-256-notes/

#
# Allows colorizing with escapes like {r} and {d}.
#
class TermColor
	
	ColorUnspecified	= 0	
	ColorDefault 			= 1	
	ColorBlack 				= 2	
	ColorRed 					= 3	
	ColorGreen 				= 4	
	ColorYellow 			= 5	
	ColorBlue 				= 6	
	ColorViolet 			= 7	
	ColorCyan 				= 8	
	ColorWhite 				= 9	
	
	ColorBoldGray 		= 10	
	ColorBoldRed 			= 11	
	ColorBoldGreen 		= 12	
	ColorBoldYellow 	= 13
	ColorBoldBlue 		= 14	
	ColorBoldViolet 	= 15	
	ColorBoldCyan 		= 16	
	ColorBoldWhite 		= 17	

	ColorBgBlack 			= 18	
	ColorBgRed 				= 19	
	ColorBgGreen 			= 20	
	ColorBgYellow 		= 21	
	ColorBgBlue 			= 22	
	ColorBgViolet 		= 23	
	ColorBgCyan 			= 24	
	ColorBgWhite 			= 25	
	
	ColorNumColors 		= 26	

  # For xterm 256 colors, put the number of the color between the prefix and suffix.
  Xterm256ColorPrefix = "\e[38;5;"
  Xterm256ColorSuffix = "m"

	@@color_codes = 
	[
		"",
		"\e[0m",
		"\e[30m",
		"\e[31m",
		"\e[32m",
		"\e[33m",
		"\e[34m",
		"\e[35m",
		"\e[36m",
		"\e[37m",

		"\e[1;30m",
		"\e[1;31m",
		"\e[1;32m",
		"\e[1;33m",
		"\e[1;34m",
		"\e[1;35m",
		"\e[1;36m",
		"\e[1;37m",

		"\e[40m",
		"\e[41m",
		"\e[42m",
		"\e[43m",
		"\e[44m",
		"\e[45m",
		"\e[46m",
		"\e[47m",
	]

	@@color_escapes = 
	{
		"d" => ColorDefault,
		"l" => ColorBlack,
		"r" => ColorRed,
		"g" => ColorGreen,
		"y" => ColorYellow,
		"b" => ColorBlue,
		"v" => ColorViolet,
		"c" => ColorCyan,
		"w" => ColorWhite,

		# i == "intense"
		"il" => ColorBoldGray, 
		"ir" => ColorBoldRed,
		"ig" => ColorBoldGreen,
		"iy" => ColorBoldYellow,
		"ib" => ColorBoldBlue,
		"iv" => ColorBoldViolet,
		"ic" => ColorBoldCyan,
		"iw" => ColorBoldWhite,

		"bl" => ColorBgBlack,
		"br" => ColorBgRed,
		"bg" => ColorBgGreen,
		"by" => ColorBgYellow,
		"bb" => ColorBgBlue,
		"bv" => ColorBgViolet,
		"bc" => ColorBgCyan,
		"bw" => ColorBgWhite,
	}

	def initialize
		reset
	end

	def reset
		@buffer = ""
		@currentPos = 0 # Current position in the string buffer
		@lastPos = 0    # Offset of last character after an escape, or the beginning of the string
		@escStart = 0   # Offset of the character where the current escape sequence began
		@inEscape = false # State. True if we are inside an escape sequence
	end

	# If the color is not valid, returns unspecified color.
	def valid_color(color)
		return ColorUnspecified if nil == color
		if color >= 0 && color < ColorNumColors
			color
		else
			ColorUnspecified
		end
	end

	def get_code(color)
		return @@color_codes[valid_color(color)]
	end

	# Change the string to be entirely the given colors.
	def colorize(fgColor, bgColor, string) 
		return get_code(bgColor) + get_code(fgColor) + string + get_code(ColorDefault)
	end

	# Get the color code that corresponds to the escape sequence
	def get_code_for_escape(escape)
		if @@color_escapes.has_key? escape
			get_code(@@color_escapes[escape])
    elsif escape =~ /^\d+$/
      # xterm 256 color escape
      Xterm256ColorPrefix + escape + Xterm256ColorSuffix
		else
			nil
		end
	end

	# Handle escape sequences of the form {r} that change the strings color.
	def colorize_with_escapes(string)
		rc = ""

		@buffer += string

		while @currentPos < @buffer.length
			c = @buffer[@currentPos,1]
			if @inEscape
				if c == "}" 
					if @currentPos == @escStart+1
						# Not an escape sequence
						@inEscape = false
					else
						escape = @buffer[(@escStart+1)..(@currentPos-1)]
						code = get_code_for_escape(escape)
						if code
							if @escStart != @lastPos
								rc = rc + @buffer[@lastPos..@escStart-1]	
							end
							rc = rc + code 
							@lastPos = @currentPos+1
						else
						end
						@inEscape = false
					end
				end
			elsif c == "{" 
				@escStart = @currentPos
				@inEscape = true
			end

			@currentPos = @currentPos + 1 
		end
		
		# If we are inside an escape sequence, then return everything to the beginning of the 
		# sequence, but keep the sequence in the buffer. If we are not in an escape sequence
		# return everything and empty the buffer.
		if @inEscape
			if @escStart != @lastPos
				rc = rc + @buffer[@lastPos..(@escStart-1)]	
			end
			if @escStart > 0
				@buffer = @buffer[@escStart..(@buffer.length-1)]
			end
			@currentPos = @buffer.length
			@lastPos = 0
			@escStart = 0
		else
			rc = rc + @buffer[@lastPos..(@currentPos-1)]	
			@buffer = ""
			@currentPos = 0
			@lastPos = 0
			@escStart = 0
		end
		rc
	end
end

class StreamColorizer
	def initialize(stream)
		@stream = stream
		@colorizer = Termcolor.new
		self
	end

	def print(s)
		@stream.print(@colorizer.colorize_with_escapes(s))
	end
	
	def puts(s)
		@stream.puts(@colorizer.colorize_with_escapes(s))
	end

	# Return a StreamColorizer for the standard output stream
	def self.stdout
		StreamColorizer.new($stdout)
	end

	def self.stderr
		StreamColorizer.new($stderr)
	end
end


