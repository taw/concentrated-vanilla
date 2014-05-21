#--
# Copyright (C) 2007,2008 William N Dortch <bill.dortch@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++
#

module Cheri
module Builder

class InstanceContext
  # TODO: defined?Java pulls it in (same as require 'java' or include Java)
  # not sure if anyone would object...
  if (defined?(::Java)) && (defined?JRUBY_VERSION) # JRuby 0.9.9 or later
    Col = java.util.Collections
    Map = java.util.HashMap
    WMap = java.util.WeakHashMap
  end

  # call-seq:
  #   InstanceContext.new(client,builder_modules) -> anInstanceContext
  #   
  def initialize(client,cfg)
#    @c = client
    @g = cfg
    # TODO: properties, aliases should probably be threadsafe hashes/maps,
    # though contention would be extremely unlikely given expected usage (any
    # puts likely to be made on the instantiating thread, immediately
    # upon instantiation).
    @p = {} # properties
    @l = {} # aliases
    # TODO: find a better way to do this    
    if self.class.const_defined?("Map")
      @h = Col.synchronized_map WMap.new
      @t = true # use Thread as key
    else
      # TODO: should use weak hash here
      # TODO: threadsafe Ruby Hash implementation?
      @h = {}
    end
  end

#  def client
#    @c  
#  end

  def cfg
    @g  
  end
  
  def auto
    @u
  end
  
  def auto?(m)
    @u && @u.include?(m)  
  end
  
  def auto!(m)
    raise BuilderException,"not an included builder module: #{m}" unless @g.include?(m)
    if @u
      @u << m unless @u.include?(m)
    else
     @u = [m]
    end
  end
  
  def props
    @p  
  end
  
  def [](k)
    @p[k]
  end
  
  def []=(k,v)
    @p[k] = v
  end
  
  def aliases
    @l
  end
  
  # call-seq:
  #   current -> context object for the current instance/thread
  #   
  def current
    key = @t ? Thread.current : Thread.current.__id__
    @h[key] ||= Context.new(self,@c)
#    Thread.current[:cheri_ctx] ||= Context.new(self,nil)
  end
  
  # Overrides the default Object#inspect to prevent mind-boggling circular displays in IRB.
  def inspect
    to_s 
  end

end #InstanceContext


class Context

  # call-seq:
  #   Context.new(instance_context,client) -> aContext
  #   
  #--
  # Key to the cryptic instance variable names:
  # 
  #   @a - any? hash - active builders (on the stack) for which any? -> true
  #   @c - the client (normally instance of class that included Cheri builder modules)
  #   @f - reference to the factories in the class's Config instance
  #   @g - reference to the class's Config instance (all included Cheri builder modules)
  #   @p - configuration properties hash, used for various purposes
  #   @i - reference to the InstanceContext that created this Context
  #   @l - reference to aliases from InstanceConfig
  #   @m - the ConnectionMinder for this context, tracks pending (prepared) connections
  #   @n - reference to the connecters in the class's Config instance
  #   @r - array of ConstantResolver instances, lazily initialized
  #   @s - the stack, holds active builders and builder frames
  #   @u - auto-factories array, lazily initialized
  #   @x - flag indicating whether instance_exec is supported, lazily initialized
  #++ 
  def initialize(ictx,client)
    @i = ictx
    cfg = @g = ictx.cfg
    @f = cfg.factories
    @n = cfg.connecters
    if (u = ictx.auto)
      @u = u.dup
    end
    @l = ictx.aliases
#    @c = client
    @m = ConnectionMinder.new
    @s = [] # stack
    @p = {} # configuration properties
  end

  def ictx
    @i  
  end
  
#  def client
#    @c
#  end

  def auto
    # same mods or both nil
    if (u = @u) == (iu = @i.auto)
      return u    
    end
    # TODO: save ref to iu to compare? otherwise we'll do this every time if
    # thread-only auto is set for one mod and instance auto is set for another.
    if iu
      if u
        u.concat(iu - u)
      else
        u = @u = iu.dup
      end    
    end
    u
  end
 
  def auto!(m)
    raise BuilderException,"not an included builder module: #{m}" unless @g.include?(m)
    (@u ||= []) << m unless @u && @u.include?(m)
  end

  # call-seq:
  #   ctx.run(builder) -> result of builder.run
  # 
  # TODO: this description sucks, rewrite.
  # 
  # Runs the specified builder. This method should be called if a builder was not created through
  # the normal Cheri factory mechanism.  This method should be called, rather than calling
  # builder.run directly, to ensure that the builder's object gets properly connected.
  def run(b)
    # run the builder
    res = b.run
    # connect it's object
    ctc(b)
    res
  end
  
  # call-seq:
  #   ctx.send(sym, *args, &block) -> matched?, result
  # 
  # Find and run a builder corresponding to +sym+.  If no match is found, try
  # to consume +sym+ as a method on the topmost object on the stack.  No exception
  # is raised by this method if a match is not found (contrast with #msend), but
  # normally an exception _will_ subsequently be raised if this method returns to
  # method_missing (the usual caller) empty-handed. 
  def send(sym,*r,&k)
    raise Cheri.type_error(sym,Symbol) unless sym.instance_of?(Symbol)
    # substitute sym for alias, if any
    sym = @l[sym] if @l[sym]
    # check args against pending connections (see note at ConnectionMinder)
    @m.ck(sym,*r)
    # first try for a builder matching sym
    if (b = bld(sym,*r,&k))
      # run it
      res = b.run
      # connect it
      ctc(b)
      return true, res
    elsif @s.empty?
      return false, nil
    else
      # no matching builder, try to consume sym as a method
      csm(sym,*r,&k)
    end
  end

  # call-seq:
  #   ctx.msend(builder_module, sym, *args, &block) -> result
  # 
  # Version of +send+ intended for use by proxy objects. The supplied module's factory
  # _must_ be able to resolve the symbol; otherwise, a NoMethodError will be raised.
  def msend(m,sym,*r,&k)
    # ok for stack to be empty for this call, so no check
    raise Cheri.type_error(sym,Symbol) unless sym.instance_of?(Symbol)
    raise ArgumentError,"not a valid builder module: #{m}" unless (f = @f[m])
    # substitute sym for alias, if any
    sym = @l[sym] if @l[sym]
    # check args against pending connections (see note at ConnectionMinder)
    @m.ck(sym,*r)
    # the factory _must_ be able to return a matching builder
    unless (b = f.builder(self,sym,*r,&k))
      raise NoMethodError,"undefined method '#{sym}' for #{m}"
    end
    # run it
    res = b.run
    # connect it
    ctc(b)
    res
  end

  # call-seq:
  #   ctx.nsend(builder_module, namespace_sym, sym, *args, &block) -> result
  # 
  # Version of +send+ intended for use by namespace objects. The supplied module's factory
  # _must_ be able to resolve the symbol; otherwise, a NoMethodError will be raised. The
  # resulting builder _must_ supply a +ns=+ method; otherwise a TypeError will be raised.
  def nsend(m,ns,sym,*r,&k)
    # ok for stack to be empty for this call, so no check
    raise Cheri.type_error(ns,Symbol) unless Symbol === ns
    raise Cheri.type_error(sym,Symbol) unless Symbol === sym
    raise ArgumentError,"not a valid builder module: #{m}" unless (f = @f[m])
    # substitute sym for alias, if any
    sym = @l[sym] if @l[sym]
    # check args against pending connections (see note at ConnectionMinder)
    @m.ck(sym,*r)
    # the factory _must_ be able to return a matching builder
    unless (b = f.builder(self,sym,*r,&k))
      raise NoMethodError,"undefined method '#{sym}' for #{m}"
    end
    raise Cheri.type_error(b,Markup) unless b.respond_to?(:ns=)
    b.ns = ns
    # run it
    res = b.run
    # connect it
    ctc(b)
    res
  end

  # call-seq:
  #   ctx.call(builder, *args, &block) -> result
  #   
  # Pushes builder onto the stack, then calls the block/proc, passing the builder's object
  # and any other arguments supplied: <tt>block.call(builder.object,*args)</tt>
  # Then pops the builder from the stack and returns the result of the call.
  # 
  # <tt>Context#call</tt> ensures that the stack is always popped, even if an exception is raised
  # in the called block.  If you choose to call the block directly, be sure to do the
  # same, otherwise failures and/or (possibly subtle) bugs will ensue.
  def call(b,*r,&k)
    push(b)
    k.call(b.object,*r)    
   ensure
    pop
  end
  
  # call-seq:
  #   ctx.eval(instance, builder, &block) -> result
  #   
  # Pushes builder onto the stack, then calls <tt>instance.instance_eval(&block)</tt>. 
  # Then pops the builder from the stack and returns the result of the <tt>instance_eval</tt>.
  # 
  # <tt>Context#eval</tt> ensures that the stack is always popped, even if an exception is raised
  # in the executed block.  If you choose to do your own instance_eval, be sure to do the
  # same, otherwise failures and/or (possibly subtle) bugs will ensue.
  def eval(i,b,&k)
    push(b)
    i.instance_eval(&k)    
   ensure
    pop
  end

  # call-seq:
  #   ctx.exec(instance, builder, *args, &block) -> result
  # 
  # Pushes builder onto the stack, then calls
  # <tt>instance.instance_exec(builder.object,*args,&block)</tt>. 
  # Then pops the builder from the stack and returns the result of the <tt>instance_exec</tt>.
  # 
  # <tt>Context#exec</tt> ensures that the stack is always popped, even if an exception is raised
  # in the executed block.  If you choose to do your own <tt>instance_exec</tt>, be sure to do the
  # same, otherwise failures and/or (possibly subtle) bugs will ensue.
  # 
  # If <tt>instance_exec</tt> is not supported on a system, the call is redirected to <tt>Context#eval</tt>
  # (<tt>instance_eval</tt>). Note that parameters will not be passed to blocks in that case.
  #--
  # TODO: need a good default instance_exec, (the one in active_support\core_ext\object\extending.rb?)
  #++
  def exec(i,b,*r,&k)
    return eval(i,b,&k) unless @x ||= (defined?instance_exec)
    push(b)
    i.instance_exec(b.object,*r,&k)    
   ensure
    pop
  end

  def push(f)
    # TODO: more checks of f (frame/builder)
    raise ArgumentError,"invalid argument - can't push: #{f}" unless f
    @s << f   
    @m.pu f
    (@a ||= []) << f if f.any?
    self
  end
  alias_method :push_frame, :push
  
  def pop
    f = @s.pop
    @m.po f
    @a.pop if f.any?
    f
  end
  alias_method :pop_frame, :pop
  
  def top
    @s.last  
  end
  alias_method :peek, :top

  def bottom
    @s.first
  end

  def each #:yields: frame
    @s.reverse_each {|v| yield v } if block_given?
  end
  alias_method :each_frame, :each
  
  def reach #:yields: frame
    @s.each {|v| yield v } if block_given?
  end
  alias_method :reverse_each, :reach
  alias_method :reverse_each_frame, :reach
    
  # call-seq:
  #   ctx.stack_size -> Fixnum
  #   ctx.size -> Fixnum
  #   ctx.length -> Fixnum
  #   
  # Returns the number of frames on the context stack.
  def size
    @s.length
  end
  alias_method :length, :size #:nodoc:
  alias_method :stack_size, :size #:nodoc:

  # call-seq:
  #   ctx.stack_empty? -> true/false
  #   ctx.empty? -> true/false
  #   
  # Returns true if the context stack is empty.
  def empty?
    @s.empty?  
  end
  alias_method :stack_empty?, :empty?
  
  # call-seq:
  #   ctx.active? -> true/false
  #   
  # Returns true if the context stack is not empty.
  def active?
    !@s.empty?
  end
  
  # call-seq:
  #   ctx.type_on_stack?(class_or_module) -> true/false
  #   ctx.tos(class_or_module) -> true/false
  # 
  # Returns true if a stack frame matches the specified class_or_module, as evaluated
  # by class_or_module === frame.
  def tos(t)
    @s.reverse_each do |f|
      return true if t === f
    end
    false
  end
  alias_method :type_on_stack?, :tos #:nodoc:

  # call-seq:
  #   ctx.builder(symbol, *args [, &block]) -> aBuilder or nil
  #   ctx.bld(symbol, *args [, &block]) -> aBuilder or nil
  # 
  # Searches the stack for a builder/frame whose associated factory can supply a
  # builder for the specified symbol (usually originating in the client's +method_missing+ method).
  # If no stack frame can supply a builder, any auto-enabled builder modules are searched
  # in the order they were enabled. Returns nil if no builder is found.
  def bld(*r,&k)
    #puts "bld args: #{[r.join(',')]}"
    queried = nil # lazily-allocated array to hold factories we've already queried
    b = nil # builder
    atf = @f
    # search stack for a frame whose module's factory can supply a matching builder
    @s.reverse_each do |s|
      if (f = atf[s.mod])
        unless queried && queried.include?(f)
          return b if (b = f.builder(self,*r,&k))
          (queried ||= []) << f
        end
      end
    end
    
    # try auto-enabled builders
    if (u = auto)
      u.each do |m|
        if (f = atf[m])
          unless queried && queried.include?(f)
            return b if (b = f.builder(self,*r,&k))
            (queried ||= []) << f
          end
        end
      end
    end
    
    # no matches
    nil
  end
  alias_method :builder, :bld #:nodoc:

  # call-seq:
  #   ctx.consume(sym, *args, &block) -> consumed?, result
  #   ctx.csm(sym, *args, &block) -> consumed?, result
  # 
  # Attempts to consume the specified +sym+, usually as a method on a built object (though
  # not necessarily; the Java on_xxx handlers are implemented through a consumer). This is
  # normally called when no builder is found matching +sym+ (which normally originates in the
  # client's method_missing method). Only the topmost stack frame is eligible to consume.
  # 
  # This method is primarily intended for internal use by Context.
  def csm(*r,&k)
    # methods are not passed up the stack; if it can't be consumed
    # by the last builder/frame, it's an error
    return false,nil unless (b = @s.last) # TODO: error if !b

    # offer the builder/object the opportunity to consume the method directly
    #puts "csm b=#{b}, b.o=#{b.object}, b.mod=#{b.mod}"
    if b.respond_to?(:consume)
      return b.consume(*r,&k)
    # must have object for standard consumers
    elsif b.object && (c = @g.consumers[b.mod])
      return c.consume(self,b,*r,&k)
    else
      return false, nil
    end
  end
  alias_method :consume, :csm #:nodoc:

  # call-seq:
  #   ctx.resolve_meth(object, method_name, args) -> resolved?
  #   ctx.mrz(object, method_name, args) -> resolved?
  # 
  # Attempts to resolve any <tt>:Constant</tt> symbols found in +args+ for the specified
  # +object+ and +method_name+. Note that +args+ must be passed as an array, not as <tt>*args</tt>,
  # as substitutions will be made directly in the array.
  def mrz(mod,o,y,a)
    if (z = @g.resolvers[mod])
      return true if z.resolve_meth(o,y,a)
    end
    false
  end
  alias_method :resolve_meth, :mrz #:nodoc:

  # call-seq:
  #  ctx.resolve_ctor(clazz, args) -> resolved?
  #  ctx.crz(clazz, args) -> resolved?
  #  
  # Attempts to resolve any <tt>:Constant</tt> symbols found in +args+ for the specified
  # +clazz+. Note that +args+ must be passed as an array, not as <tt>*args</tt>,
  # as substitutions will be made directly in the array.
  def crz(mod,c,a)
    #puts "resolving: m=#{mod}, c=#{c}, a=[#{a.join(',')}]"
    if (z = @g.resolvers[mod])
      return true if z.resolve_ctor(c,a)
    end
    false
  end
  alias_method :resolve_ctor, :crz #:nodoc:
  

  def ctc(frame)
    # make sure there's something to connect to, and the frame wants to connect
    return if @s.empty? || !frame.child?

    # offer the builder/object the opportunity to connect itself
    return if frame.respond_to?(:connect) && frame.connect(self)
    
    # we need sym and object for standard connecters
    return unless (sym = frame.sym) && (obj = frame.object)

    # connect properties are optional (used in swing/awt for add constraints, etc.)
    props = frame.respond_to?(:props) ? frame.props : nil

    # find the first (closest) frame/builder on the stack that has an object
    # we can connect to
    parent = nil
    @s.reverse_each do |b|
      if b.parent? && b.object
        parent = b
        break
      end
    end

    #puts "frame.object #{obj}"
    #puts "parent #{parent}" 
    # if we got a builder (parent), attempt to connect it
    if parent && (n = @n[parent.mod])
      #puts "parent.mod #{n}"
      n.prepare(self,parent,obj,sym,props)
    end
    
    # now attempt connections for any 'any' objects on the stack
    if @a
      @ax = true
      begin
      @a.reverse_each do |a|
        if a.object && (n = @n[a.mod])
          n.prepare(self,a,obj,sym,props)
        end
      end
      ensure
      @ax = nil
      end
    end

    nil
  end
  private :ctc
  alias_method :connect, :ctc

  def cfg
    @g  
  end

  def props
    @p
  end

  # call-seq:
  #   ctx[key] -> value
  #   
  def [](k)
    @p[k]
  end
  
  # call-seq:
  #   ctx[key] = value -> value
  #   
  def []=(k,v)
    @p[k]=v  
  end
  
  # call-seq:
  #   ctx.aliases -> aliases hash
  #   ctx.als -> aliases hash
  # 
  def als
    @l  
  end
  # :stopdoc:
  alias_method :aliases, :als
  # :startdoc:


  # call-seq:
  #   prepared(connecter,builder,obj,sym,props=nil) -> true
  #   ppd(connecter,builder,obj,sym,props=nil) -> true
  #   
  # Called by a Connecter (normally) from its +prepare+ method (normally) to indicate
  # that it is prepared to connect +obj+ to the parent object hosted by +builder+. The
  # context will later call the connecter's +connect+ method to perform the actual
  # connection, provided the pending connection has not been invalidated. (A pending
  # connection will be invalidated if +obj+ is passed as a parameter to a method or
  # constructor <em>invoked via Cheri</em>; the assumption is that the receiver will
  # have performed any connection necessary.)
  # 
  # Note that if you are using TypeConnecter (highly recommended where appropriate), this all
  # takes place behind the scenes, so you don't need to call this method directly.
  def ppd(ctr,bldr,obj,sym,props=nil)
    unless @ax
      @m.ppd(ctr,bldr,obj,sym,props)
    else
      @m.ppda(ctr,bldr,obj,sym,props)
    end
  end
  alias_method :prepared, :ppd #:nodoc:

  # Overrides the default Object#inspect to prevent mind-boggling circular displays in IRB.
  def inspect
    to_s 
  end

  # We want to prevent built objects passed as parameters from
  # being dynamically connected, since presumably the method/ctor
  # being called will do whatever is needed (except for cherify,
  # which _wants_ its arg connected). Note that we can only catch
  # those passed to cheri-invoked ctors/methods.
  class ConnectionMinder # :nodoc: all
    def initialize
      @c = {} # pending connections. indexed by builder.__id__
      #@a = {} # pending 'any' connections. indexed by builder.__id__
      @o = {} # pending builder(object)s. indexed by object.__id__
    end

    # a builder has been pushed onto the stack. create
    # an array to hold pending connections for that builder
    def pu(b)
      @c[b.__id__] = []
    end
    alias_method :pushed, :pu #:nodoc:
    
    # a builder has been popped from the stack. connect any
    # pending (prepared) connections, and remove each builder/object
    # associated with a connection from the pending objects hash.
    def po(b)
      if @a && (ac = @a.delete b.__id__)
        ac.each do |c|
          c.connect rescue nil
        end
      end
      if (cs = @c.delete b.__id__)
        begin
          cs.each do |c| c.connect; end
        ensure
          o = @o
          cs.each do |c| o.delete c.obj.__id__; end
        end    
      end
    end
    alias_method :popped, :po #:nodoc:
    
    # store a prepared connection.
    def ppd(ctr,bldr,obj,sym,props=nil)
      @o[obj.__id__] = bldr
      @c[bldr.__id__] << Conn.new(ctr,bldr.object,obj,sym,props)
      true
    end
    alias_method :prepared, :ppd #:nodoc:

    # store a prepared 'any' connection.
    def ppda(ctr,bldr,obj,sym,props=nil)
      ((@a ||= {})[bldr.__id__] ||= []) << Conn.new(ctr,bldr.object,obj,sym,props)
      true
    end
    alias_method :prepared_any, :ppda # :nodoc:

    # check args passed to ctors/methods against the pending objects hash,
    # and remove any matches from the pending connections/objects hashes.
    def ck(y,*r)
      unless r.empty? || y == :cheri_yield || y == :cherify
        o = @o
        r.each do |a|
          if (b = o[a.__id__])
            cs = @c[b.__id__]
            cs.reverse_each do |c|
              if a.equal?(c.obj)
                cs.delete(c)
                o.delete(a.__id__)
              end
            end
          end
        end
        if Hash === r.last
          r.last.each_value do |a|
            if (b = o[a.__id__])
              cs = @c[b.__id__]
              cs.reverse_each do |c|
                if a.equal?(c.obj)
                  cs.delete(c)
                  o.delete(a.__id__)
                end
              end
            end
          end
        end     
      end
    end
    alias_method :check, :ck #:nodoc:

    class Conn # :nodoc: all
      def initialize(ctr,par,obj,sym,props)
        @c = ctr
        @p = par
        @o = obj
        @y = sym if sym
        @r = props if props
      end
      def obj
        @o
      end
      def connect
        @c.connect(@p,@o,@y,@r)
      end
    end #Con
  end #ConnectionMinder
end #Context

end #Builder
end #Cheri

