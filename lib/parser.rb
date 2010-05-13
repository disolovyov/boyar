# encoding: utf-8
require 'enumerator'
require 'error'

class Parser
  def initialize(lexer, interpreter)
    @lexer = lexer
    @interpreter = interpreter
    @status = '[ Летопись нетронута ]'
  end
  
  def next_lexeme
    @lexeme_enum ||= Enumerator.new do |result|
      @lexer.lexemes.each {|lexeme| result << lexeme }
      loop { result << nil }
    end
    @lexeme = @lexeme_enum.next
  end

  def lexeme_expected
    unexpected_end unless @lexeme
  end

  def next_lexeme_expected
    next_lexeme
    lexeme_expected
  end

  def lexeme_is(_class)
    @lexeme[:class] == _class
  end

  def lexeme_is_static(words)
    (@lexeme[:class] == :static) && (
      words.is_a?(Array)?
      words.include?(@lexeme[:word]) :
      words == @lexeme[:word]
    )
  end
  
  def parse
    next_lexeme_expected
    parse_static('летопись')
    parse_identifier
    parse_static(',')
    parse_statement_until('любо')
    next_lexeme
    while @lexeme
      termination_error unless lexeme_is_static(',')
      next_lexeme
    end
    @interpreter.emit(:halt)
    @status = '[ Летопись прочитана ]'
    self
  end
  
  def parse_statement_until(static_end)
    parse_statement until lexeme_is_static(static_end)
  end
  
  def parse_statement
    if lexeme_is_static('бьюсь') then parse_bius
    elsif lexeme_is_static('пущай') then parse_pusai
    elsif lexeme_is_static('узрите') then parse_uzrite
    elsif lexeme_is_static('ой') then parse_oi
    elsif lexeme_is_static('покуда') then parse_pokuda
    elsif lexeme_is_static('паче') then parse_pace
    elsif lexeme_is_static(',') then next_lexeme_expected
    else
      grammar_error(
        '%s "бьюсь", "ой", "паче", "покуда", "пущай", "узрите" али ","' %
        boyar_class(:static)
      )
    end
  end
  
  def parse_bius
    next_lexeme_expected
    parse_static('челом')
    parse_static('за')
    parse_identifier
    if lexeme_is_static('допреж')
      next_lexeme_expected
      parse_static('того')
      parse_expression
    else
      @interpreter.emit(:push)
    end
    @interpreter.emit(:store)
  end
  
  def parse_pusai
    next_lexeme_expected
    parse_identifier
    parse_static('знаменует')
    parse_expression
    @interpreter.emit(:store)
  end
  
  def parse_uzrite
    next_lexeme_expected
    parse_expression
    @interpreter.emit(:print)
  end
  
  def parse_oi
    next_lexeme_expected
    parse_static('ли')
    parse_expression
    parse_static(',')
    arg = @interpreter.emit_relocated(:jump_false)
    parse_statement_until(['коли', 'убо'])
    if lexeme_is_static('коли')
      next_lexeme_expected
      parse_static('не')
      arg_new = @interpreter.emit_relocated(:jump)
      @interpreter.emit_label(arg)
      arg = arg_new
      parse_statement_until('убо')
    end
    next_lexeme_expected
    @interpreter.emit_label(arg)
  end
  
  def parse_pokuda
    next_lexeme_expected
    return_to = @interpreter.locate
    parse_expression
    parse_static(',')
    arg = @interpreter.emit_relocated(:jump_false)
    parse_statement_until('убо')
    next_lexeme_expected
    @interpreter.emit(:jump, return_to)
    @interpreter.emit_label(arg)
  end
  
  def parse_pace
    next_lexeme_expected
    parse_static(',')
    arg = @interpreter.locate
    parse_statement_until('покамест')
    next_lexeme_expected
    parse_expression
    @interpreter.emit(:jump_true, arg)
  end
  
  def parse_expression
    parse_equality
    while lexeme_is_static(['али', 'и'])
      if lexeme_is_static('али')
        proc = :or
      else
        proc = :and
      end
      next_lexeme_expected
      parse_equality
      @interpreter.emit(proc)
    end
  end
  
  def parse_equality
    parse_comparable
    while lexeme_is_static(['ни', 'як'])
      if lexeme_is_static('ни')
        next_lexeme_expected
        parse_static('як')
        proc = :not_equal
      else
        next_lexeme_expected
        proc = :equal
      end
      parse_comparable
      @interpreter.emit(proc)
    end
  end
  
  def parse_comparable
    parse_arithmetic
    while lexeme_is_static(['богаче', 'убоже'])
      if lexeme_is_static('богаче')
        proc = :greater
      else
        proc = :less
      end
      next_lexeme_expected
      if lexeme_is_static('али')
        next_lexeme_expected
        parse_static('як')
        if proc == :greater
          proc = :greater_or_equal
        else
          proc = :less_or_equal
        end
      end
      parse_arithmetic
      @interpreter.emit(proc)
    end
  end
  
  def parse_arithmetic
    parse_term
    while lexeme_is_static(['без', 'да', 'к'])
      if lexeme_is_static('без')
        next_lexeme_expected
        proc = :subtract
      elsif lexeme_is_static('да')
        next_lexeme_expected
        proc = :add
      else
        next_lexeme_expected
        parse_static('сему')
        proc = :concatenate
      end
      parse_term
      @interpreter.emit(proc)
    end
  end
  
  def parse_term
    parse_factor
    while lexeme_is_static(['на', 'от', 'по'])
      if lexeme_is_static('на')
        proc = :multiply
      elsif lexeme_is_static('от')
        proc = :modulo
      else
        proc = :divide
      end
      next_lexeme_expected
      parse_factor
      @interpreter.emit(proc)
    end
  end
  
  def parse_factor
    if lexeme_is_static('ни')
      next_lexeme_expected
      parse_factor
      @interpreter.emit(:not)
    else
      parse_group
    end
  end
  
  def parse_group
    if lexeme_is(:identifier)
      @interpreter.emit(:push, @lexer.identifiers.index(@lexeme[:word]))
      @interpreter.emit(:load)
      next_lexeme_expected
    elsif lexeme_is(:constant)
      @interpreter.emit(:push, @lexeme[:word])
      next_lexeme_expected
    elsif lexeme_is_static('отселе')
      next_lexeme_expected
      parse_expression
      parse_static('доселе')
    else
      grammar_error(
        '%s, %s или %s "отселе"' %
        [
          boyar_class(:identifier),
          boyar_class(:constant),
          boyar_class(:static)
        ]
      )
    end
  end
  
  def parse_static(word)
    unless lexeme_is_static(word)
      grammar_error('%s "%s"' % [boyar_class(:static), word])
    end
    next_lexeme_expected
  end

  def parse_identifier
    grammar_error(boyar_class(:identifier)) unless lexeme_is(:identifier)
    @interpreter.emit(:push, @lexer.identifiers.index(@lexeme[:word]))
    next_lexeme_expected
  end
  
  def boyar_class(_class)
    case _class
    when :identifier then 'имя'
    when :static then 'начертание'
    when :constant then 'благо'
    else ''
    end
  end
  
  def termination_error
    raise BoyarError, 'Скорбная кончина!'
  end

  def grammar_error(expected)
    raise BoyarError,
      'Испрошаем %s на строке %d в столбце %d, а не %s "%s"!' % [
        expected,
        @lexeme[:line_number],
        @lexeme[:col_number],
        boyar_class(@lexeme[:class]),
        @lexeme[:word]
      ]
  end
  
  def to_s
    @status
  end
end