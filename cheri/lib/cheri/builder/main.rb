#--
# Copyright (C) 2007,2008,2009 William N Dortch <bill.dortch@gmail.com>
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

class BuilderException < Cheri::CheriException; end

class << self
  def append_features(clazz) #:nodoc:
#    return super unless clazz.instance_of?(Class) &&
#       !clazz.instance_variable_get(:@__cheri_cfg).instance_of?(Config)
    return super unless Class === clazz &&
       !(Config === clazz.instance_variable_get(:@__cheri_cfg))
    clazz.instance_variable_set(:@__cheri_cfg,Config.new(CheriModule))
    # we don't support subclassing for builder modules installed at the
    # top level (in Object). method_missing will be inherited, but will
    # behave normally (just calls super if @__cheri_cfg not installed)
    unless clazz == Object
      clazz.module_eval do 
        class << self
          def inherited(subclass)
            cfg = @__cheri_cfg
            subclass.module_eval do
              # copy modules unless a more-derived subclass has already done so
              unless @__cheri_cfg.instance_of?(Cheri::Builder::Config)
                @__cheri_cfg = cfg.copy
              end
            end
            # pass it up the chain
            super
          end
          private :inherited
        end      
      end
    end
    super
  end
  private :append_features  

  # call-seq:
  #   Cheri::Builder.module_included(module, class) -> Cheri::Builder
  #
  # Installs the specified module as a Cheri builder for the specified class.  Note
  # that the 'included module' needn't be included, or even a module, in order to
  # participate as a Cheri builder, though normally it will be both.
  # 
  # Modules should hook the <tt>append_features</tt> method, rather than <tt>included</tt>;
  # the former allows inclusion to be aborted if exceptional conditions arise, whereas
  # the latter is called after the fact:
  # 
  #   module MyBuilder
  #     include Cheri::Builder
  #     class << self
  #       def append_features(clazz)
  #         Cheri::Builder.module_included(self, clazz)
  #         super # allow inclusion to complete
  #       end
  #       private :append_features
  #     end #self
  #   
  #   end #MyBuilder
  # 
  # Builders installed for a class will be inherited by its subclasses, with the 
  # exception of those installed for class Object; inclusion of Builder modules in
  # Object is discouraged, but is permitted so simple scripts can include builders
  # at the top level rather than having to define a class.  But really, don't do it.
  def module_included(mod,clazz)
    return self unless clazz.instance_of?(Class)
    append_features(clazz)
    clazz.instance_variable_get(:@__cheri_cfg) << mod
    self
  end

  # note: Cheri::Java needs factory method

  # Create a new builder module using the BuilderBuilder.
  def new_builder(*r,&k)
    # TODO: usage message if no args or block supplied
    Generator.new(*r,&k).run
  end
  
end #self


  # Instance methods


  # call-seq:
  #   method_missing(symbol [, *args] [, &block]) -> result (if method matched)
  #   
  def method_missing(sym,*r,&k)
    # get the context for the current thread
    if (ctx = __cheri_ctx)
      # send to the context for processing
      matched, result = ctx.send(sym,*r,&k)
      # return the result if sym matched      
      return result if matched
    end
    
    # nothing matches, probable NameError/NoMethodError
    super
  end
  private :method_missing

  # call-seq:
  #   cheri([*args] [, &block]) -> CheriProxy if no block given, else result of block
  #   
  def cheri(*r,&k)
    if (ctx = __cheri_ctx)
      if k
        CheriFrame.new(ctx,*r,&k).run
      else
        ctx[:cheri_proxy] ||= CheriProxy.new(ctx,*r)
      end
    end
  end
  private :cheri


  # call-seq:
  #   __cheri_ctx -> context object for the current instance/thread
  #
  def __cheri_ctx
    unless (ic = @__cheri_ctx)
      # don't create context unless we're an installed Cheri module
      # (this is part of the solution for preventing Cheri modules installed
      # at the top level (in Object) from being unintentionally inherited)
      return unless (g = self.class.instance_variable_get(:@__cheri_cfg)).instance_of?(Config)
      # using ||= in case another thread slipped by us
      # TODO: is ||= actually atomic?
      ic = @__cheri_ctx ||= InstanceContext.new(self,g)
    end
    ic.current
  end
  private :__cheri_ctx

# Module used by cheri(){} method. Supplies pseudo-factory that
# searches all installed factories.
module CheriModule

  # Returns CheriFactory
  def self.factory
    CheriFactory  
  end

  # Factory used by cheri(){} method - searches all installed
  # factories.
  module CheriFactory
    # Searches all factories, in the reverse order their
    # modules were included.
    def self.builder(ctx,*r,&k)
      ctx.cfg.mods.reverse_each do |m|
        if m != CheriModule && m.respond_to?(:factory) && (f = m.factory)
          if (b = f.builder(ctx,*r,&k))
            return b        
          end
        end
      end
      nil
    end
  end
end

# a base class for proxies
class BaseProxy
  alias_method :__methods__,:methods
  keep = /^(__|<|>|=)|^(class|inspect|to_s)$|(\?|!|=)$/
  instance_methods.each do |m|
    undef_method m unless m =~ keep  
  end

class << self
  def impl(meths)
    meths.each do |m|
      self.module_eval <<-EOM
        def #{m}(*r,&k)
          @ctx.msend(mod,:#{m},*r,&k)
        end
      EOM
    end
  end
  private :impl
end #self

  def initialize(ctx,*r)
    @ctx = ctx
  end

  # override to return builder module
  def mod
    CheriModule  
  end
  private :mod

  # call-seq:
  #   vget(:@var) -> @var in client instance
  #   
  # Returns the value of the specified instance variable in client. Provided
  # for use when instance_eval / instance_exec are used to evaluate blocks 
  # (:block_method => :eval or :block_method => :exec)
  def vget(sym)
    @ctx.client.instance_variable_get(sym)
  end
  
  # call-seq:
  #   vset(:@var, value) -> @var in client instance
  #   
  # Sets the value of the specified instance variable in client. Provided
  # for use when instance_eval / instance_exec are used to evaluate blocks 
  # (:block_method => :eval or :block_method => :exec)
  def vset(sym,val)
    @ctx.client.instance_variable_set(sym,val)  
  end

  # prevent mind-boggling circular displays in IRB
  def inspect
    "#<#{self.class}:instance>"  
  end  
  
  def method_missing(*r,&k)
    @ctx.msend(mod,*r,&k)
  end
  private :method_missing

end #BaseProxy

class CheriProxy < BaseProxy
  def [](*args)
    h = Hash === args.last ? args.pop : {}
    args.each {|a| h[a] = true}
    h.each_pair do |name,value|
      raise Cheri.type_error(name,Symbol) unless Symbol === name
      case name
        when :alias
          if Array === value
            raise ArgumentError,"odd number of values for :alias" if ((len = value.length) & 1) == 1
            v = {}
            (len>>1).times {|i| v[value[i*2]] = value[i*2+1] }
            value = v
          else
            raise Cheri.type_error(value,Hash,Array) unless Hash === value
          end
          aliases = @ctx.aliases
          value.each_pair do |als,name|
            als = als.to_sym if String === als
            name = name.to_sym if String === name
            raise Cheri.type_error(als,Symbol,String) unless Symbol === als
            raise Cheri.type_error(name,Symbol,String) unless Symbol === name
            aliases[als] = name
          end
        else raise NameError,"unknown cheri[] option #{name}"
      end
    end
  end
end  #CheriProxy

class CheriFrame
  include Frame
  def initialize(ctx,*r,&k)
    super
    @obj = ctx[:cheri_proxy] ||= CheriProxy.new(ctx,*r)  
  end
  def mod
    CheriModule  
  end
end #CheriFrame

class BaseOptions < Hash
  def initialize(opts=nil)
    raise Cheri.type_error(opts,self.class,Hash) if opts && !(Hash === opts)
    super()
    merge!(opts) if opts
  end

  def store(key,value)
    val = validate(key,value)
    if nil == val
      delete(key)
    else
      super(key,val)
    end
  end
  #alias_method :store,:[]=

  def validate_boolean(value)
    raise Cheri.type_error(value,TrueClass,FalseClass,NilClass) unless true == value || false == value
    value
  end
  
  def validate_boolean_nil(value)
    raise Cheri.type_error(value,TrueClass,FalseClass,NilClass) unless true == value || false == value || nil == value
    value
  end
  
  def validate_fixnum(value)
    raise Cheri.type_error(value,Fixnum) unless Fixnum === value
    value
  end

  def validate_fixnum_nil(value)
    raise Cheri.type_error(value,Fixnum) unless Fixnum === value || nil == value
    value
  end
  
  def validate_symbol(value)
    raise Cheri.type_error(value,Symbol) unless Symbol === value
    value
  end
  
  def validate_string(value)
    raise Cheri.type_error(value,String) unless String === value
    value
  end

  def merge(other)
    raise Cheri.type_error(other,self.class,Hash) unless Hash === other
    opts = self.dup
    other.each_pair {|k,v| opts.store(k,v) }
    opts
  end
  
  def merge!(other)
    raise Cheri.type_error(other,self.class,Hash) unless Hash === other
    other.each_pair {|k,v| store(k,v) }
    self
  end
  
  def ingest_args(*args)
    args.each do |arg|
      if Symbol === arg
        store(arg,true)
      elsif Hash === arg
        merge!(arg)
      else
        raise Cheri.type_error(arg,Symbol,Hash)
      end
    end
    self
  end
end #BaseOptions

module DefaultConsumer 
G = 'get_' #:nodoc:
S = 'set_' #:nodoc:
I = 'is_'  #:nodoc:

  # call-seq:
  #   DefaultConsumer.consume(context,builder,sym,*args,&block) -> consumed?, ret_val
  #
  def self.consume(ctx,bld,sym,*args,&k)
    obj = bld.object
    s = sym.to_s
    # if sym is already clearly a getter/setter/is-er (xxx=, xxx?, get_xxx, set_xxx, is_xxx),
    # then leave it as is.
    # (Note: tested the following line against s =~ /((\?|=)$|^(get_|set_|is_))/ - this is about
    # 50% faster in MRI (C) Ruby, but currently slower in JRuby (0.9.9)...)
    if (c = s[-1]) == ?= || c == ?? || s.rindex(G,0) || s.rindex(S,0) || s.rindex(I,0)
      snd = sym
    # otherwise, if there are args and the sym works as a setter (xxx=), then prefer
    # that to a getter.
    elsif !args.empty? && obj.respond_to?(snd = s << ?= ) # TODO: careful, what if sym was String?
    # otherwise leave it as is
    else
      snd = sym
    end
    if obj.respond_to?(snd)
      if !args.empty? && bld.respond_to?(:resolve?) && bld.resolve?
        # context.resolve_method_constants(object,send_sym,args)
        ctx.mrz(obj,snd,args)
      end
      res = nil
      begin
        res = obj.__send__(snd, *args)
      rescue
        return false,nil
      end
      # here's our little inside-out trick. really no different than saying
      # obj1().obj2()...objn().doSomething(), except that multiple operations
      # can be performed in the scope of the block. a bit like JavaScript's
      # 'with' statement in that respect.
      if k && res

        # TODO: update comments
        # 
        # get a cheri_yield builder for the return value and run it. the
        # builder is obtained through the context rather than created directly,
        # as different builders are used for different types of objects (Java vs.
        # non-Java, for instance).
        ctx.send(:cheri_yield,res,&k)
      end
      return true,res
    end
    return false,nil # consumed,ret_val
  end #consume

end #DefaultConsumer


# TODO: comments
# The connecter of last resort
DefaultConnecter = TypeConnecter.new do
  Eq = '=' 
  St = 'set_'
  
  type Object do
    connect Object do |parent,obj,sym,props|
      if parent.respond_to?(snd = (s = sym.to_s) + Eq) ||
          parent.respond_to?(snd = St + s) ||
          parent.respond_to?(snd = :add)
        parent.__send__(snd,obj) rescue nil
      end
      nil 
    end  
  end
end


# The ConstantResolver classes/modules are designed primarily for use with
# Java classes, for which constant name specification/qualification can be
# especially onerous.  This _might_ find some use in pure Ruby applications;
# the mechanism (substituting values for :Constant symbols found in constructor
# or method arguments) could conceivably be repurposed in interesting ways.
# Meanwhile, it was cleaner to define this here, rather than having to maintain
# separate versions of Context and all the attendant fuss.
class AbstractConstantResolver
  # note that we pass args, not *args, as we want the original array
  def resolve_ctor(clazz,args)
    false
  end
  
  def resolve_meth(object,method_name,args)
    false
  end
end #AbstractConstantResolver

class CherifyBuilder < BaseBuilder
  def initialize(context,sym,object,*args,&block)
    super(context,sym,*args,&block)
    @obj = object
    @clazz = object.class
    @no_create = true
  end
end #CherifyBuilder

class CheriYieldBuilder < BaseBuilder
  def initialize(context,sym,object,*args,&block)
    super(context,sym,*args,&block)
    @obj = object
    @clazz = object.class
    @no_create = true
    @not_child = true
  end
end #CheriYieldBuilder

module CherifyFactory # < Cheri::AbstractFactory
  def self.builder(context,sym,*args,&block)
    return nil unless sym == :cherify
    # TODO: validate second arg is hash if present
    raise Cheri.argument_error(args.length, 1..2) unless args.length == 1 || args.length == 2
    CherifyBuilder.new(context,sym,*args,&block)
  end
end #CherifyFactory

# TODO: comments
module CheriYieldFactory # < Cheri::AbstractFactory
  def self.builder(context,sym,*args,&block)
    return nil unless sym == :cheri_yield    
    raise Cheri.argument_error(args.length, 1) unless args.length == 1
    CheriYieldBuilder.new(context,sym,*args,&block)
  end
end #CheriYieldFactory

# A do-nothing factory. May be safley returned by the +factory+ method
# of builder modules that don't supply builders
module NilFactory
  def self.builder(*r,&k)
  end
end

module NilConnecter
  def self.prepare(*r)
  end
end


class Aggregate < Array
  def initialize(*args,&k)
    args.each do |a|
      self << a    
    end
    yield self if block_given?
  end
  alias_method :app, :<<
  #protected :app # broken in JRuby 1.0.0RC-1
  def <<(elem)
    app(elem) unless include?(elem)
  end
end #Aggregate

# class to aggregate factories
class SuperFactory < Aggregate
  def builder(ctx,sym,*r,&k)
    each do |f|
      if (b = f.builder(ctx,sym,*r,&k))
        return b
      end
    end 
    nil 
  end
end #SuperFactory


# class to aggregate connecters
class SuperConnecter < Aggregate
  def prepare(*r)
    each do |ctr|
      return true if ctr.prepare(*r)    
    end
    false
  end
end

# class to aggregate consumers
class SuperConsumer < Aggregate
  def consume(*r,&k)
    each do |cns|
      c, v = cns.consume(*r,&k)
      return c,v if c
    end
    return false, nil     
  end
end #SuperConsumer

# class to aggregate resolvers
# TODO: the Java resolver won't play nicely right now; raises if it fails to resolve
class SuperResolver < Aggregate
  def resolve_ctor(*r)
    each do |rsv|
      return true if rsv.resolve_ctor(*r)    
    end
    false
  end
  def resolve_meth(*r)
    each do |rsv|
      return true if rsv.resolve_meth(*r)
    end
    false
  end
end


DefaultFactory = SuperFactory.new do |f|
  f << CherifyFactory  
  f << CheriYieldFactory
end

# BuildType used with generic factories/builders
class BuildType
  BLD_PARENT = 1 << 0
  BLD_CHILD  = 1 << 1
  BLD_ANY    = 1 << 2
  BLD_DEFAULT = BLD_PARENT | BLD_CHILD

  def initialize(clazz,sym=nil,&k)
    raise Cheri.type_error(clazz,Class) unless Class === clazz
    @clazz = clazz
    if sym
      raise Cheri.type_error(sym,Symbol) unless Symbol === sym
      @sym = sym
    end
    @flags = BLD_DEFAULT
    instance_eval(&k) if k
  end
    
  def clazz
    @clazz
  end
    
  def sym
    @sym    
  end
    
  def sym=(sym)
    raise Cheri.type_error(sym,Symbol) unless Symbol === sym
    @sym = sym
  end
    
  def flags
    @flags || BLD_DEFAULT
  end
    
  def build_as(*opts)
    @flags = 0
    opts.each do |opt|
      raise Cheri.type_error(opt,Symbol) unless Symbol === opt
      case opt
        when :parent     : @flags |= BLD_PARENT
        when :child      : @flags |= BLD_CHILD
        when :parent_any : @flags |= BLD_ANY
        when :default    : @flags |= BLD_DEFAULT
        else
          raise ArgumentError,"invalid build_as type: #{opt}"
      end
    end
    @flags = BLD_DEFAULT if @flags == 0
  end
  
  def parent?
    (@flags & BLD_PARENT) != 0
  end
  
  def child?
    (@flags & BLD_CHILD) != 0
  end
  
  def any?
    (@flags & BLD_ANY) != 0
  end
    
  def ==(other)
    if BuildType === other
      @clazz == other.clazz 
    else
      @clazz == other
    end
  end
    
  def eql?(other)
    if BuildType === other
      @clazz.eql?(other.clazz)
    else
      @clazz.eql?(other)
    end
  end
  
end #BuildType

class BuildTypes < Hash
  def []=(sym,type)
    raise Cheri.type_error(sym,Symbol) unless Symbol === sym
    raise Cheri.type_error(type,BuildType) unless BuildType === type
    super
  end
  alias_method :store,:[]=

  def invert
    inv = {}
    each_pair do |sym,type|
      inv[type.clazz] = sym
    end
    inv
  end
end #BuildTypes

end #Builder
end #Cheri
