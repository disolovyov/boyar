class Scope
  @@top = nil
  
  def initialize
    @parent = @@top
    @@top = self
    @entries = {}
  end
  
  def get(id)
    if @entries.include?(id) then @entries[id]
    elsif @parent then @parent.get(id)
    else nil
    end
  end
  
  def set(id)
    @entries[id] = {
      :offset => @entries.size,
      :global => @parent == nil
    } unless @entries.include?(id)
  end
  
  def close
    @@top = @parent
  end
  
  def self.top
    @@top
  end
end