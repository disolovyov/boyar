# encoding: utf-8
require 'unicode'
require 'grammar'
require 'error'

class Lexer
  attr_reader :lexemes, :identifiers
  
  def initialize(ios)
    @source = ios.read.chomp.gsub(/[\n\r]+/, "\n") + ' '
    @lexemes = []
    @identifiers = []
  end
  
  def scan
    @current_line = 1
    @current_col = 1
    @state = :idle
    @word = ''
    @source.each_char do |char|
      @char = char
      @word += char
      @token = get_token
      scan_token
      if @char == "\n"
        @current_line += 1
        @current_col = 1
      else
        @current_col += 1
      end
    end
    unterminated_string if @state == :string
    finish_state unless @state == :idle
    self
  end
  
  def get_token
    token = TOKENS.each do |token, chars|
      return token if chars.include? Unicode::downcase(@char)
    end
    unless token.is_a?(Symbol)
      unknown_symbol unless PERMISSIVE_STATES.include? @state
      token = :symbol
    end
    token
  end
  
  def scan_token
    @new_state = STATES[@state][@token]
    unexpected_symbol if @new_state == :error
    if @state != @new_state
      finish_state
      @state = @new_state
    end
  end
  
  def finish_state
    case @state
    when :idle
      begin_word
    when :identifier
      push_identifier
      push_delimiter
    when :number
      @word.slice!(-1)
      push_table(:constant)
      push_delimiter
    when :string
      @word = @word[1..-2]
      push_table(:constant)
    when :comment
      if COMMENT_END.include? @char
        push_delimiter
      else
        @new_state = :comment
      end
    end
  end
  
  def begin_word
    @word = @char
    @word_line = @current_line
    @word_col = @current_col
  end
  
  def push_identifier
    @word = Unicode::downcase(@word[0..-2])
    if COMMENT_BEGIN.include? @word
      @new_state = :comment
    else
      if index = STATIC.index(@word)
        push_table(:static, index)
      else
        @identifiers += [@word] unless @identifiers.include? @word
        push_table(:identifier, @identifiers.index(@word))
      end
    end
  end
  
  def push_delimiter
    if @token == :delimiter
      @word_col += @word.size
      @word = ','
      push_table(:static)
    end
  end
  
  def push_table(_class, index = nil)
    @lexemes += [
      :class => _class,
      :word => @word,
      :index => index,
      :line_number => @word_line,
      :col_number => @word_col
    ]
  end
  
  def unknown_symbol
    raise BoyarError,
      'Бесовское начертание "%s" на строке %d в столбце %d!' %
      [@char, @current_line, @current_col]
  end 
  
  def unexpected_symbol
    raise BoyarError,
      'Неблагое начертание "%s" на строке %d в столбце %d!' %
      [@char, @current_line, @current_col]
  end
  
  def unterminated_string
    raise BoyarError,
      'Скорбная кончина на строке %d в столбце %d!' %
      [@current_line, @current_col]
  end
  
  def to_s
    formatted = "[ Слова ]:\n"
    @lexemes.each do |lexeme|
      lexeme_name = lexeme[:class].to_s
      lexeme_name += ", %d" % lexeme[:index] if lexeme[:index]
      lexeme_location = '%d:%d' % [lexeme[:line_number], lexeme[:col_number]]
      formatted +=
        "%-15s   %-7s   %s\n" %
        [lexeme_name, lexeme_location, lexeme[:word]]
    end
    formatted += "\n[ Блага ]:\n"
    id_format = "%%%dd  %%s\n" % @identifiers.length.to_s.length
    @identifiers.each_index do |index|
      formatted += id_format % [index, @identifiers[index]]
    end
    formatted
  end
end