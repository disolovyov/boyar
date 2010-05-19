# encoding: utf-8
require 'enumerator'
require 'error'
require 'scope'

class Parser
  def initialize(lexer, emitter)
    @lexer = lexer
    @emitter = emitter
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
    grammar_error(boyar_class(:identifier)) unless lexeme_is(:identifier)
    next_lexeme_expected
    parse_static(',')
    Scope.new
    parse_main
    next_lexeme
    while @lexeme
      termination_error unless lexeme_is_static(',')
      next_lexeme
    end
    @emitter.emit(:halt)
    @status = '[ Летопись прочитана ]'
    self
  end
  
  def parse_main
    until lexeme_is_static('любо')
      if lexeme_is_static('бьюсь')
        parse_function
      else
        parse_statement_until(['бьюсь', 'любо'])
      end
    end
  end
  
  def parse_function
    next_lexeme_expected
    parse_static('челом')
    parse_static('за')
    grammar_error(boyar_class(:identifier)) unless lexeme_is(:identifier)
    id = @lexer.identifiers.index(@lexeme[:word])
    redeclared_error if @emitter.function_declared(id)
    next_lexeme_expected
    Scope.new
    arg = @emitter.emit_relocated(:jump)
    @emitter.emit_function(id)
    @emitter.emit(:frame_down)
    parse_locals
    parse_static(',')
    parse_statement_until('убо')
    next_lexeme_expected
    @emitter.emit(:push, 0)
    @emitter.emit(:frame_up)
    @emitter.emit(:return)
    @emitter.emit_label(arg)
    Scope.top.close
  end
  
  def parse_locals
    vars = []
    while lexeme_is_static('с')
      next_lexeme_expected
      grammar_error(boyar_class(:identifier)) unless lexeme_is(:identifier)
      vars += [
        Scope.top.set(@lexer.identifiers.index(@lexeme[:word]))
      ]
      next_lexeme_expected
    end
    vars.reverse.each do |var|
      @emitter.emit_variable(var)
      @emitter.emit(:store)
    end
  end
  
  def parse_statement_until(static_end)
    parse_statement until lexeme_is_static(static_end)
  end
  
  def parse_statement
    if lexeme_is_static('доставляше') then parse_dostavlase
    elsif lexeme_is_static('ой') then parse_oi
    elsif lexeme_is_static('сотворим') then parse_sotvorim
    elsif lexeme_is_static('паче') then parse_pace
    elsif lexeme_is_static('покуда') then parse_pokuda
    elsif lexeme_is_static('пущай') then parse_pusai
    elsif lexeme_is_static('узрите') then parse_uzrite
    elsif lexeme_is_static(',') then next_lexeme_expected
    else
      grammar_error(
        '%s "бьюсь", "ой", "паче", "покуда", "пущай", "узрите" али ","' %
        boyar_class(:static)
      )
    end
  end
  
  def parse_dostavlase
    next_lexeme_expected
    parse_expression
    if Scope.top.parent
      @emitter.emit(:frame_up)
      @emitter.emit(:return)
    else
      @emitter.emit(:halt)
    end
  end
  
  def parse_oi
    next_lexeme_expected
    parse_static('ли')
    parse_expression
    parse_static(',')
    arg = @emitter.emit_relocated(:jump_false)
    parse_statement_until(['коли', 'убо'])
    if lexeme_is_static('коли')
      next_lexeme_expected
      parse_static('не')
      arg_new = @emitter.emit_relocated(:jump)
      @emitter.emit_label(arg)
      arg = arg_new
      parse_statement_until('убо')
    end
    next_lexeme_expected
    @emitter.emit_label(arg)
  end
  
  def parse_sotvorim
    next_lexeme_expected
    grammar_error(boyar_class(:identifier)) unless lexeme_is(:identifier)
    var = Scope.top.set(@lexer.identifiers.index(@lexeme[:word]))
    next_lexeme_expected
    if lexeme_is_static('допреж')
      next_lexeme_expected
      parse_static('того')
      parse_expression
      @emitter.emit_variable(var)
      @emitter.emit(:store)
    end
  end
  
  def parse_pace
    next_lexeme_expected
    parse_static(',')
    arg = @emitter.locate
    parse_statement_until('покамест')
    next_lexeme_expected
    parse_expression
    @emitter.emit(:jump_true, arg)
  end
  
  def parse_pokuda
    next_lexeme_expected
    return_to = @emitter.locate
    parse_expression
    parse_static(',')
    arg = @emitter.emit_relocated(:jump_false)
    parse_statement_until('убо')
    next_lexeme_expected
    @emitter.emit(:jump, return_to)
    @emitter.emit_label(arg)
  end
  
  def parse_pusai
    next_lexeme_expected
    grammar_error(boyar_class(:identifier)) unless lexeme_is(:identifier)
    lexeme = @lexeme
    next_lexeme_expected
    parse_static('знаменует')
    parse_expression
    parse_variable(lexeme)
    @emitter.emit(:store)
  end
  
  def parse_uzrite
    next_lexeme_expected
    parse_expression
    @emitter.emit(:print)
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
      @emitter.emit(proc)
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
      @emitter.emit(proc)
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
      @emitter.emit(proc)
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
      @emitter.emit(proc)
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
      @emitter.emit(proc)
    end
  end
  
  def parse_factor
    if lexeme_is_static('ни')
      next_lexeme_expected
      parse_factor
      @emitter.emit(:not)
    else
      parse_item
    end
  end
  
  def parse_item
    if lexeme_is(:identifier)
      parse_item_identifier
    elsif lexeme_is(:constant)
      parse_item_constant
    elsif lexeme_is_static('отселе')
      parse_item_group
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
  
  def parse_item_identifier
    lexeme = @lexeme
    next_lexeme_expected
    if lexeme_is_static(['деяши', 'с'])
      parse_function_call(lexeme)
    else
      parse_variable(lexeme)
      @emitter.emit(:load)
    end
  end
  
  def parse_function_call(lexeme)
    if lexeme_is_static('с')
      while lexeme_is_static('с')
        next_lexeme_expected
        parse_expression
      end
      parse_static('твориши')
    else
      parse_static('деяши')
    end
    @emitter.emit_call(@lexer.identifiers.index(lexeme[:word]))
  end
  
  def parse_item_constant
    @emitter.emit(:push, @lexeme[:word])
    next_lexeme_expected
  end
  
  def parse_item_group
    next_lexeme_expected
    parse_expression
    parse_static('доселе')
  end
  
  def parse_static(word)
    unless lexeme_is_static(word)
      grammar_error('%s "%s"' % [boyar_class(:static), word])
    end
    next_lexeme_expected
  end
  
  def parse_variable(lexeme)
    var = Scope.top.get(@lexer.identifiers.index(lexeme[:word]))
    unless var
      @lexeme = lexeme
      undeclared_error
    end
    @emitter.emit_variable(var)
  end
  
  def boyar_class(_class)
    case _class
    when :identifier then 'благо'
    when :static then 'начертание'
    when :constant then 'слово'
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
  
  def undeclared_error
    raise BoyarError,
      'Незаявленное благо "%s" на строке %d в столбце %d!' % [
        @lexeme[:word],
        @lexeme[:line_number],
        @lexeme[:col_number]
      ]
  end
  
  def redeclared_error
    raise BoyarError,
      'Виданное благо "%s" на строке %d в столбце %d!' % [
        @lexeme[:word],
        @lexeme[:line_number],
        @lexeme[:col_number]
      ]
  end
  
  def to_s
    @status
  end
end