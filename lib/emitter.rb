# encoding: utf-8
class Emitter
  attr_reader :pcode
  
  def initialize
    @pcode = []
    @relocations = []
    @addresses = []
    @functions = {}
    @built = false
  end
  
  def emit(proc, arg = nil)
    @pcode += [
      :proc => proc,
      :arg => arg
    ]
  end
  
  def emit_relocated(proc)
    @addresses += [nil]
    arg = @addresses.size - 1
    emit(proc, arg)
    address = @pcode.size - 1
    @relocations += [address]
    arg
  end
  
  def emit_label(address)
    @addresses[address] = @pcode.size
  end
  
  def emit_variable(var)
    emit(:push, var[:offset])
    unless var[:global]
      emit(:frame_shift)
      emit(:add)
    end
  end
  
  def function_declared(id)
    @addresses[@functions[id]] if @functions.include?(id)
  end
  
  def set_function(id)
    unless @functions.include?(id)
      @functions[id] = @addresses.size
      @addresses += [nil]
    end
  end
  
  def emit_function(id)
    set_function(id)
    @addresses[@functions[id]] = @pcode.size
  end
  
  def emit_call(id)
    set_function(id)
    @relocations += [@pcode.size]
    emit(:call, @functions[id])
  end
  
  def locate
    @pcode.size
  end
  
  def build
    unless @built
      @relocations.each do |address|
        @pcode[address][:arg] = @addresses[@pcode[address][:arg]]
      end
      @built = true
    end
    self
  end
  
  def to_s
    pcode = "[ P-код ]:\n"
    length = @pcode.size.to_s.size
    i = 0
    @pcode.each do |line|
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