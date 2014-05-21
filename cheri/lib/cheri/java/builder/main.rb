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

# cheri/java/builder/main

module Cheri
module Java
module Builder
#:stopdoc:
CJava = Cheri::Java
CBuilder = Cheri::Builder
#:startdoc:
class << self
  def append_features(clazz)
    CBuilder.module_included(self,clazz)
    super
  end
  private :append_features
  
  def factory
    DefaultFactory  
  end
  
  def consumer
    DefaultConsumer  
  end
  
  def connecter
    DefaultConnecter
  end
  
  def resolver
  end

#  def consume(*r,&k)
#    DefaultConsumer.consume(*r,&k)
#  end
#  
#  def prepare(*r)
#    DefaultConnecter.prepare(*r)  
#  end
  
end #self

class BaseBuilder < Cheri::Builder::BaseBuilder
  def initialize(ctx,sym,*args,&block)
    super
    @props = @args.pop if Hash === args.last
  end

  def mod
    Cheri::Java::Builder
  end

  def run
    pre
    # we add the resolve_ctor method, not defined in Cheri::Builder::BaseBuilder
    resolve_ctor if @resolve
    create unless @no_create
    post
    call unless @no_call
    @obj
  end

  def props
    @props
  end

  def resolve?
    @resolve  
  end

private
  # called if @resolve is set, before object created
  def resolve_ctor
    @ctx.crz(mod, @clazz, @args) if @clazz && @args && !@args.empty?
  end

end #BaseBuilder

class ClassBuilder < BaseBuilder
  def initialize(ctx,sym,clazz,*args,&block)
    super(ctx,sym,*args,&block)
    @clazz = clazz
    # TODO: I don't know if we want this as default...
    # *ANSWER* yes, because a :SYMBOL will never be a valid Java arg,
    # and doing it this way simplifies adding later Java types and constants.
    # The first simple_resolve check is cheap, so this won't hurt performance
    @resolve = true
  end
private
  def create
    @obj = @clazz.new(*@args)
    def @obj.java_class
      self.class.java_class
    end if BUG_JRUBY_3476
  end
end #ClassBasedBuilder

class ProcBuilder < BaseBuilder
  def initialize(ctx,sym,proc,*args,&block)
    super(ctx,sym,*args,&block)
    @proc = proc
  end
private
  def create
    @obj = @proc.call(*@args)
    @clazz = @object.class
    @resolve = true
  end
end #ProcBasedBuilder

class CherifyBuilder < BaseBuilder
  def initialize(ctx,sym,object,*args,&block)
    super(ctx,sym,*args,&block)
    @obj = object
    @clazz = object.class
    @no_create = true
    @resolve = true
  end
end #CherifyBuilder

class CheriYieldBuilder < BaseBuilder
  def initialize(ctx,sym,object,*args,&block)
    super(ctx,sym,*args,&block)
    @obj = object
    @clazz = object.class
    @no_create = true
    @not_child = true
    @resolve = true
  end
end #CheriYieldBuilder

# TODO: comments
module CherifyFactory # < Cheri::AbstractFactory
  def self.builder(ctx,sym,*args,&block)
    return nil unless sym == :cherify && args[0].respond_to?(:java_class)
    raise Cheri.argument_error(args.length,1..2) unless args.length == 1 || args.length == 2
    CherifyBuilder.new(ctx,sym,*args,&block)
  end
end #CherifyFactory

# TODO: comments
module CheriYieldFactory # < Cheri::AbstractFactory
  def self.builder(ctx,sym,*args,&block)
    return nil unless sym == :cheri_yield && args[0].respond_to?(:java_class)
    raise Cheri.argument_error(args.length,1) unless args.length == 1
    CheriYieldBuilder.new(ctx,sym,*args,&block)
  end
end #CheriYieldFactory

DefaultFactory = Cheri::Builder::SuperFactory.new do |f|
  f << CherifyFactory  
  f << CheriYieldFactory
end

# The Java connecter of last resort
DefaultConnecter = Cheri::Builder::TypeConnecter.new do
  U = Cheri::Java::Builder::Util

  type java.lang.Object do
    connect java.lang.Object do |parent,obj,sym,props|
      snd = U.setter?(s = sym.to_s) ? sym : U.setter(s)
      if parent.respond_to?(snd) ||
          parent.respond_to?(snd = s << ?= ) ||
          parent.respond_to?(snd = :add)
        #puts "Java::DefaultConnecter for #{parent},\n #{obj}: #{snd}"
        parent.__send__(snd,obj) rescue nil
      end    
    end  
  end

end

module GenericConsumer
Util = Cheri::Java::Builder::Util
G = 'get'
S = 'set'
I = 'is'
E = '='
class << self
  def consume(ctx,bld,sym,*args,&k)
    #puts "JGC: #{sym}"
    return false,nil unless (obj = bld.object).respond_to?(:java_class)
    s = sym.to_s
    # if sym is already an accessor, use it as is

    if Util.acc?(s)
      snd = sym
    else
      cc = Util.cc(s) #upper-camel-cased name
      if ((!args.empty?) && (obj.respond_to?(snd = S + cc) || obj.respond_to?(snd = s + E )))
      elsif obj.respond_to?(snd = G + cc)
      elsif obj.respond_to?(snd = I + cc)
      else
         snd = sym
      end
    end
    #puts "JGC: snd = #{snd}"
    if obj.respond_to?(snd)
      if !args.empty? && bld.respond_to?(:resolve?) && bld.resolve?
        ctx.mrz(bld.mod,obj,snd,args)
      end
      
      # TODO: do we want to rescue here? maybe better to fail noisily...
      
      #res = nil
      #begin
        res = obj.__send__(snd, *args)
      #rescue
        #return false,nil
      #end
      if k && res
        ctx.send(:cheri_yield,res,&k)
      end
      return true,res
    end
    return false,nil # consumed,res
  end
end #self
end #DefaultConsumer

module EventMethodConsumer
#:stopdoc:
On = 'on_'.freeze
Eq = '='.freeze
# TODO: any other useful aliases?
Aliases = {:on_click => 'actionPerformed'.freeze}
#:startdoc:
  def self.consume(ctx,bld,sym,*args,&block)
    return false,nil unless (obj = bld.object).respond_to?(:java_class) &&
      ((method_name = Aliases[sym]) || (s = sym.to_s).rindex(On,0))
    method_name ||= Util.lcc(s[3,s.length])
    unless (info = Interfaces.get_listener_info(obj.java_class||obj.class.java_class,method_name))
      raise NameError,"no Java interface found matching event handler name: #{sym}"
    end
    raise ArgumentError,"missing block for event handler: #{sym}" unless block
    listener = Interfaces.get_listener_impl(info).new
    listener.__send__(method_name + Eq , block)
    obj.__send__(info.add_method_name,listener)
    return true,listener
  end
end #EventMethodConsumer

DefaultConsumer = Cheri::Builder::SuperConsumer.new do |cns|
  cns << EventMethodConsumer
  cns << GenericConsumer
end

class ConstantResolver < Cheri::Builder::AbstractConstantResolver
  Const = Cheri::Java::Builder::Constants
  def initialize(*sources,&k)
    @sources = []
    @cache = {}
    sources.each do |s|
      self << s    
    end
    yield self if block_given?
  end

  # note that we pass args, not *args, as we want the original array
  def resolve_ctor(clazz,args)
    return false unless clazz.respond_to?(:java_class)
    Const.resolve_ctor(clazz,args,self)
  end

  # note that we pass args, not *args, as we want the original array
  def resolve_meth(object,sym,args)
    return false unless object.respond_to?(:java_class)
    Const.resolve_meth(object.class,sym,args,self)
  end

  def add_constant_source(source)
    # not much of a validity check, better than none...
    unless source.respond_to?(:get)
      raise Cheri::CheriException,"invalid constants source specified: #{source}"
    end
    unless @sources.include?(source)
      @sources << source
      # flush the cache
      @cache.clear 
    end
  end
  alias_method :<<, :add_constant_source

  def get(constant)
    rec_arr = @cache[constant]
    return (rec_arr == :no_match ? nil : rec_arr) if rec_arr
    @sources.each do |s|
      const_rec = s.get(constant)
      while const_rec
        (rec_arr ||= []) << const_rec
        const_rec = const_rec.next_rec
      end
    end
    @cache[constant] = rec_arr || :no_match
    rec_arr
  end

  def copy
    self.class.allocate.copy_from(@sources)
  end

  protected
  def copy_from(sources)
    @sources = sources.dup
    @cache = {}
    self
  end
end #ConstantResolver

class GenericClassBuilder < ClassBuilder
  # TODO: eliminate ClassBuilder inheritance?
  def initialize(mod,type,ctx,sym,*args,&block)    
    super(ctx,sym,type.clazz,*args,&block)
    @mod = mod
    @type = type
  end
  def mod
    @mod  
  end
  def parent?
    @type.parent?  
  end
  def child?
    @type.child?
  end
  def any?
    @type.any?
  end
end #GenericClassBuilder


class GenericCherifyBuilder < CherifyBuilder
  def initialize(mod,*r,&k)
    super(*r,&k)
    @mod = mod
  end
  def mod
    @mod  
  end
end #GenericCherifyBuilder

class GenericCheriYieldBuilder < CheriYieldBuilder
  def initialize(mod,*r,&k)
    super(*r,&k)
    @mod = mod
  end
  def mod
    @mod  
  end
end #GenericCheriYieldBuilder

class GenericBuilderFactory
  # :stopdoc:
  BuildType = Cheri::Builder::BuildType
  BuildTypes = Cheri::Builder::BuildTypes
  # :startdoc:
  def initialize(mod,types)
    raise Cheri.type_error(types,BuildType) unless BuildTypes === types
    @mod = mod
    @types = types
    @inv = types.invert
  end
  def builder(ctx,sym,*r,&k)
    if (type = @types[sym])
      GenericClassBuilder.new(@mod,type,ctx,sym,*r,&k)
    elsif @inv[r.first.class]
      if sym == :cherify
        GenericCherifyBuilder.new(@mod,ctx,sym,*r,&k)
      elsif sym == :cheri_yield
        GenericCheriYieldBuilder.new(@mod,ctx,sym,*r,&k)
      else
        nil
      end
    else
      nil
    end
  end
end #GenericBuilderFactory

class PackageFactory
  # :stopdoc:
  Dot = '.'
  CJ = Cheri::Java
  BuildType = Cheri::Builder::BuildType
  BuildTypes = Cheri::Builder::BuildTypes
  #Util = Cheri::Java::Builder::Util
  # :startdoc:
  def initialize(pkg_str,mod)
    raise Cheri.type_error(pkg_str,String) unless String === pkg_str
    @pkg = pkg_str.empty? || pkg_str[-1] == ?. ? pkg_str.dup : pkg_str + Dot
    @mod = mod
    @types = BuildTypes.new
  end
  def builder(ctx,sym,*r,&k)
    unless type = @types[sym]
      if clazz = CJ.get_class(@pkg + Util.cc(sym)) rescue nil
        type = @types[sym] = BuildType.new(clazz,sym)
      else
        type = @types[sym] = :none
      end
    end
    unless type == :none
      GenericClassBuilder.new(@mod,type,ctx,sym,*r,&k)
    else
      nil
    end
  end
end #PackageFactory

end #Builder
end #Java
end #Cheri
