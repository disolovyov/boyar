class Interpreter
  attr_accessor :identifiers
  
  def initialize
    @code = []
    @relocations = []
    @addresses = []
    @compiled = false
  end
  
  def emit(proc, arg = nil)
    @code += [
      :proc => proc,
      :arg => arg
    ]
  end
  
  def emit_relocated(proc)
    @addresses += [nil]
    arg = @addresses.size - 1
    emit(proc, arg)
    address = @code.size - 1
    @relocations += [address]
    arg
  end
  
  def emit_label(address)
    @addresses[address] = @code.size
  end
  
  def relocate_labels
    @relocations.each do |address|
      @code[address][:arg] = @addresses[@code[address][:arg]]
    end
  end
  
  def locate
    @code.size
  end
  
  def optimize
    self
  end
  
  def compile
    relocate_labels
    optimize
    @compiled = true
    self
  end
  
  def run
    compile unless @compiled
    @stack = []
    @identifiers = []
    @pointer = 0
    while @code[@pointer][:proc] != :halt
      if @code[@pointer][:arg]
        send(@code[@pointer][:proc], @code[@pointer][:arg])
      else
        send(@code[@pointer][:proc])
      end
      @pointer += 1
    end
    self
  end
  
  # Run-time functions
  
  def add
    push(int(pop) + int(pop))
  end
  
  def and
    push(int(bool(pop) && bool(pop)))
  end
  
  def bool(arg)
    int(arg) != 0
  end
  
  def concatenate
    arg = pop.to_s
    push(pop.to_s + arg)
  end
  
  def divide
    arg = int(pop)
    push(int(pop) / arg)
  end
  
  def equal
    push(int(int(pop) == int(pop)))
  end
  
  def greater
    arg = int(pop)
    push(int(int(pop) > arg))
  end
  
  def greater_or_equal
    arg = int(pop)
    push(int(int(pop) >= arg))
  end
  
  def int(arg)
    if arg.is_a? String
      return 0 unless arg.size
      arg.to_i
    elsif (arg.is_a? TrueClass) || (arg.is_a? FalseClass)
      arg ? 1 : 0
    else
      arg.to_i
    end
  end
  
  def jump_true(arg)
    jump(arg) if bool(pop)
  end
  
  def jump_false(arg)
    jump(arg) unless bool(pop)
  end
  
  def jump(arg)
    @pointer = arg - 1
  end
  
  def less
    arg = int(pop)
    push(int(int(pop) < arg))
  end
  
  def less_or_equal
    arg = int(pop)
    push(int(int(pop) <= arg))
  end
  
  def load
    push(@identifiers[pop])
  end
  
  def modulo
    arg = int(pop)
    push(int(pop) % arg)
  end
  
  def multiply
    push(int(pop) * int(pop))
  end
  
  def not
    push(int(!bool(pop)))
  end
  
  def not_equal
    push(int(int(pop) != int(pop)))
  end
  
  def or
    push(int(bool(pop) || bool(pop)))
  end
  
  def pop
    @stack.pop
  end
  
  def print
    puts pop
  end
  
  def push(arg)
    @stack.push(arg)
  end
  
  def store
    arg = pop
    @identifiers[pop] = arg
  end
  
  def subtract
    push(int(pop) - int(pop))
  end
  
  # End of run-time functions
  
  def to_s
    pcode = ''
    length = @code.size.to_s.size
    i = 0
    @code.each do |line|
      if line[:arg]
        pcode += "%%%dd: %%s, %%s\n" % length % [i, line[:proc], line[:arg]]
      else
        pcode += "%%%dd: %%s\n" % length % [i, line[:proc]]
      end
      i += 1
    end
    pcode
  end
end