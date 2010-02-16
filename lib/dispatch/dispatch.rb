# Convenience methods for invoking GCD 
# directly from the top-level Dispatch module

module Dispatch
  # Asynchronously run the +&block+  
  # on a concurrent queue of the given (optional) +priority+
  #
  #   Dispatch.async {p "Did this later"}
  # 
  def async(priority=nil, &block)
    Dispatch::Queue.concurrent(priority).async &block
  end

  # Asynchronously run the +&block+ inside a Future
  # -- which is returned for use with +join+ or +value+ --
  # on a concurrent queue of the given (optional) +priority+
  #
  #   f = Dispatch.fork { 2+2 }
  #   f.value # => 4
  # 
  def fork(priority=nil, &block)
    Dispatch::Future.new(priority) { block.call }
  end

  # Asynchronously run the +&block+ inside a Group
  # -- which is created if not specified, and
  # returned for use with +wait+ or +notify+ --
  # on a concurrent queue of the given (optional) +priority+
  #
  #   g = Dispatch.group {p "Do this"}
  #   Dispatch.group(g) {p "and that"}
  #   g.wait # => "Do this" "and that"
  # 
  def group(grp=nil, priority=nil, &block)
    grp ||= Dispatch::Group.new
    Dispatch::Queue.concurrent(priority).async(grp) { block.call } if not block.nil?
    grp
  end

  # Returns a mostly unique reverse-DNS-style label based on
  # the ancestor chain and ID of +obj+ plus the current time
  # 
  #   Dispatch.labelize(Array.new)
  #   => Dispatch.enumerable.array.0x2000cc2c0.1265915278.97557
  #
  def labelize(obj)
    names = obj.class.ancestors[0...-2].map {|a| a.to_s.downcase}
    label = names.uniq.reverse.join(".")
    "#{self}.#{label}.%p.#{Time.now.to_f}" % obj.object_id
  end

  # Returns a new serial queue with a unique label based on +obj+
  # (or self, if no object is specified)
  # used to serialize access to objects called from multiple threads
  #
  #   a = Array.new
  #   q = Dispatch.queue(a)
  #   q.async {a << 2 }
  #
  def queue(obj=self, &block)
    q = Dispatch::Queue.new(Dispatch.labelize(obj))
    q.async { block.call } if not block.nil?
    q
  end

  # Applies the +&block+ +count+ number of times in parallel
  # -- passing step (default 1) iterations at a time --
  # on a concurrent queue of the given (optional) +priority+
  # 
  #   @sum = 0
  #   Dispatch.upto(10, 3) { |j| @sum += j }
  #   p @sum # => 55
  #
  def upto(count, step=1, priority=nil, &block)
    q = Dispatch::Queue.concurrent(priority)
    n_steps = (count / step).to_int
    q.apply(n_steps) do |i|
      j0 = i*step
      j0.upto(j0+step) { |j| block.call(j); puts "j=#{j}" }
    end
    # Runs the remainder (if any) sequentially
    (n_steps*step).upto(count) { |j| block.call(j); puts "j'=#{j}" }
  end

  # Wrap the passed +obj+ (or its instance, if a Class) inside an Actor
  # to serialize access and allow asynchronous returns
  #
  #   a = Dispatch.wrap(Array)
  #   a << Time.now # automatically serialized
  #   a.size # => 1 (synchronous return)
  #   a.size {|n| p "Size=#{n}"} # => "Size=1" (asynchronous return)
  #
  def wrap(obj)
    Dispatch::Actor.new( (obj.is_a? Class) ? obj.new : obj)
  end

  module_function :async, :fork, :group, :queue, :wrap, :labelize

end
