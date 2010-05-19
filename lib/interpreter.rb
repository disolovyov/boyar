class Interpreter
  def run(pcode)
    @stack = []
    @calls = []
    @variables = {}
    @frames = []
    @frame_offset = 0
    @pointer = 0
    while pcode[@pointer][:proc] != :halt
      if pcode[@pointer][:arg]
        send(pcode[@pointer][:proc], pcode[@pointer][:arg])
      else
        send(pcode[@pointer][:proc])
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
  
  def call(arg)
    @calls.push(@pointer + 1)
    jump(arg)
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
  
  def frame_down
    @frames.push(@frame_offset)
    @frame_offset = @variables.size
  end
  
  def frame_shift
    @stack.push(@frame_offset)
  end
  
  def frame_up
    @frame_offset = @frames.pop
    @variables.reject! {|key| key >= @frame_offset }
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
    push(@variables[pop])
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
  
  def return
    jump(@calls.pop)
  end
  
  def store
    @variables[pop] = pop
  end
  
  def subtract
    push(int(pop) - int(pop))
  end
  
  # End of run-time functions
end