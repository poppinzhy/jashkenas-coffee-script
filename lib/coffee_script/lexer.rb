module CoffeeScript

  # The lexer reads a stream of CoffeeScript and divvys it up into tagged
  # tokens. A minor bit of the ambiguity in the grammar has been avoided by
  # pushing some extra smarts into the Lexer.
  class Lexer

    # The list of keywords passed verbatim to the parser.
    KEYWORDS   = ["if", "else", "then", "unless",
                  "true", "false", "yes", "no", "on", "off",
                  "and", "or", "is", "isnt", "not",
                  "new", "return",
                  "try", "catch", "finally", "throw",
                  "break", "continue",
                  "for", "in", "of", "by", "where", "while",
                  "delete", "instanceof", "typeof",
                  "switch", "when",
                  "super", "extends"]

    # Token matching regexes.
    IDENTIFIER = /\A([a-zA-Z$_](\w|\$)*)/
    NUMBER     = /\A(\b((0(x|X)[0-9a-fA-F]+)|([0-9]+(\.[0-9]+)?(e[+\-]?[0-9]+)?)))\b/i
    STRING     = /\A(""|''|"(.*?)([^\\]|\\\\)"|'(.*?)([^\\]|\\\\)')/m
    HEREDOC    = /\A("{6}|'{6}|"{3}\n?(.*?)\n?([ \t]*)"{3}|'{3}\n?(.*?)\n?([ \t]*)'{3})/m
    JS         = /\A(``|`(.*?)([^\\]|\\\\)`)/m
    OPERATOR   = /\A([+\*&|\/\-%=<>:!?]+)/
    WHITESPACE = /\A([ \t]+)/
    COMMENT    = /\A(((\n?[ \t]*)?#.*$)+)/
    CODE       = /\A((-|=)>)/
    REGEX      = /\A(\/(.*?)([^\\]|\\\\)\/[imgy]{0,4})/
    MULTI_DENT = /\A((\n([ \t]*))+)(\.)?/
    LAST_DENT  = /\n([ \t]*)/
    ASSIGNMENT = /\A(:|=)\Z/

    # Token cleaning regexes.
    JS_CLEANER      = /(\A`|`\Z)/
    MULTILINER      = /\n/
    STRING_NEWLINES = /\n[ \t]*/
    COMMENT_CLEANER = /(^[ \t]*#|\n[ \t]*$)/
    NO_NEWLINE      = /\A([+\*&|\/\-%=<>:!.\\][<>=&|]*|and|or|is|isnt|not|delete|typeof|instanceof)\Z/
    HEREDOC_INDENT  = /^[ \t]+/

    # Tokens which a regular expression will never immediately follow, but which
    # a division operator might.
    # See: http://www.mozilla.org/js/language/js20-2002-04/rationale/syntax.html#regular-expressions
    NOT_REGEX  = [
      :IDENTIFIER, :NUMBER, :REGEX, :STRING,
      ')', '++', '--', ']', '}',
      :FALSE, :NULL, :TRUE
    ]

    # Tokens which could legitimately be invoked or indexed.
    CALLABLE = [:IDENTIFIER, :SUPER, ')', ']', '}', :STRING]

    # Scan by attempting to match tokens one character at a time. Slow and steady.
    def tokenize(code)
      @code    = code.chomp # Cleanup code by remove extra line breaks
      @i       = 0          # Current character position we're parsing
      @line    = 1          # The current line.
      @indent  = 0          # The current indent level.
      @indents = []         # The stack of all indent levels we are currently within.
      @tokens  = []         # Collection of all parsed tokens in the form [:TOKEN_TYPE, value]
      @spaced  = nil        # The last value that has a space following it.
      while @i < @code.length
        @chunk = @code[@i..-1]
        extract_next_token
      end
      puts "original stream: #{@tokens.inspect}" if ENV['VERBOSE']
      close_indentation
      Rewriter.new.rewrite(@tokens)
    end

    # At every position, run through this list of attempted matches,
    # short-circuiting if any of them succeed.
    def extract_next_token
      return if identifier_token
      return if number_token
      return if heredoc_token
      return if string_token
      return if js_token
      return if regex_token
      return if indent_token
      return if comment_token
      return if whitespace_token
      return    literal_token
    end

    # Tokenizers ==========================================================

    # Matches identifying literals: variables, keywords, method names, etc.
    def identifier_token
      return false unless identifier = @chunk[IDENTIFIER, 1]
      # Keywords are special identifiers tagged with their own name,
      # 'if' will result in an [:IF, "if"] token.
      tag = KEYWORDS.include?(identifier) ? identifier.upcase.to_sym : :IDENTIFIER
      tag = :LEADING_WHEN if tag == :WHEN && [:OUTDENT, :INDENT, "\n"].include?(last_tag)
      @tokens[-1][0] = :PROTOTYPE_ACCESS if tag == :IDENTIFIER && last_value == '::'
      if tag == :IDENTIFIER && last_value == '.' && !(@tokens[-2] && @tokens[-2][1] == '.')
        if @tokens[-2][0] == "?"
          @tokens[-1][0] = :SOAK_ACCESS
          @tokens.delete_at(-2)
        else
          @tokens[-1][0] = :PROPERTY_ACCESS
        end
      end
      token(tag, identifier)
      @i += identifier.length
    end

    # Matches numbers, including decimals, hex, and exponential notation.
    def number_token
      return false unless number = @chunk[NUMBER, 1]
      token(:NUMBER, number)
      @i += number.length
    end

    # Matches strings, including multi-line strings.
    def string_token
      return false unless string = @chunk[STRING, 1]
      escaped = string.gsub(STRING_NEWLINES, " \\\n")
      token(:STRING, escaped)
      @line += string.count("\n")
      @i += string.length
    end

    # Matches heredocs, adjusting indentation to the correct level.
    def heredoc_token
      return false unless match = @chunk.match(HEREDOC)
      doc = match[2] || match[4]
      indent = doc.scan(HEREDOC_INDENT).min
      doc.gsub!(/^#{indent}/, "")
      doc.gsub!("\n", "\\n")
      doc.gsub!('"', '\\"')
      token(:STRING, "\"#{doc}\"")
      @line += match[1].count("\n")
      @i += match[1].length
    end

    # Matches interpolated JavaScript.
    def js_token
      return false unless script = @chunk[JS, 1]
      token(:JS, script.gsub(JS_CLEANER, ''))
      @i += script.length
    end

    # Matches regular expression literals.
    def regex_token
      return false unless regex = @chunk[REGEX, 1]
      return false if NOT_REGEX.include?(last_tag)
      token(:REGEX, regex)
      @i += regex.length
    end

    # Matches and consumes comments.
    def comment_token
      return false unless comment = @chunk[COMMENT, 1]
      @line += comment.scan(MULTILINER).length
      token(:COMMENT, comment.gsub(COMMENT_CLEANER, '').split(MULTILINER))
      token("\n", "\n")
      @i += comment.length
    end

    # Record tokens for indentation differing from the previous line.
    def indent_token
      return false unless indent = @chunk[MULTI_DENT, 1]
      @line += indent.scan(MULTILINER).size
      @i += indent.size
      next_character = @chunk[MULTI_DENT, 4]
      no_newlines = next_character == '.' || (last_value.to_s.match(NO_NEWLINE) && @tokens[-2][0] != '.'  && !last_value.match(CODE))
      return suppress_newlines(indent) if no_newlines
      size = indent.scan(LAST_DENT).last.last.length
      return newline_token(indent) if size == @indent
      if size > @indent
        token(:INDENT, size - @indent)
        @indents << (size - @indent)
      else
        outdent_token(@indent - size)
      end
      @indent = size
    end

    # Record an oudent token or tokens, if we're moving back inwards past
    # multiple recorded indents.
    def outdent_token(move_out)
      while move_out > 0 && !@indents.empty?
        last_indent = @indents.pop
        token(:OUTDENT, last_indent)
        move_out -= last_indent
      end
      token("\n", "\n")
    end

    # Matches and consumes non-meaningful whitespace.
    def whitespace_token
      return false unless whitespace = @chunk[WHITESPACE, 1]
      @spaced = last_value
      @i += whitespace.length
    end

    # Multiple newlines get merged together.
    # Use a trailing \ to escape newlines.
    def newline_token(newlines)
      token("\n", "\n") unless last_value == "\n"
      true
    end

    # Tokens to explicitly escape newlines are removed once their job is done.
    def suppress_newlines(newlines)
      @tokens.pop if last_value == "\\"
      true
    end

    # We treat all other single characters as a token. Eg.: ( ) , . !
    # Multi-character operators are also literal tokens, so that Racc can assign
    # the proper order of operations.
    def literal_token
      value = @chunk[OPERATOR, 1]
      tag_parameters if value && value.match(CODE)
      value ||= @chunk[0,1]
      tag = value.match(ASSIGNMENT) ? :ASSIGN : value
      if !@spaced.equal?(last_value) && CALLABLE.include?(last_tag)
        tag = :CALL_START  if value == '('
        tag = :INDEX_START if value == '['
      end
      token(tag, value)
      @i += value.length
    end

    # Helpers ==========================================================

    # Add a token to the results, taking note of the line number.
    def token(tag, value)
      @tokens << [tag, Value.new(value, @line)]
    end

    # Peek at the previous token's value.
    def last_value
      @tokens.last && @tokens.last[1]
    end

    # Peek at the previous token's tag.
    def last_tag
      @tokens.last && @tokens.last[0]
    end

    # A source of ambiguity in our grammar was parameter lists in function
    # definitions (as opposed to argument lists in function calls). Tag
    # parameter identifiers in order to avoid this. Also, parameter lists can
    # make use of splats.
    def tag_parameters
      return if last_tag != ')'
      i = 0
      loop do
        i -= 1
        tok = @tokens[i]
        return if !tok
        case tok[0]
        when :IDENTIFIER  then tok[0] = :PARAM
        when ')'          then tok[0] = :PARAM_END
        when '('          then return tok[0] = :PARAM_START
        end
      end
    end

    # Close up all remaining open blocks. IF the first token is an indent,
    # axe it.
    def close_indentation
      outdent_token(@indent)
    end

  end
end