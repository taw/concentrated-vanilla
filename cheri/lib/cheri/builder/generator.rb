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

class Generator
  module Template
  class << self
    def append_features(clazz)
      Cheri::Builder.module_included(@ext,clazz) if @ext
      Cheri::Builder.module_included(self,clazz)
      super
    end
    private :append_features
      
    def factory
      @fct  
    end
  
    def connecter
      @ctr  
    end
  
    def consumer
      @cns  
    end
  end #self
  end #Template
  
  class TypeBuilder
    include Cheri::Builder::Builder
    def initialize(mod,type,*r,&k)
      super(*r,&k)
      @mod = mod
      @type = type
      @clazz = type.clazz
    end
    # returns the module to which this builder belongs
    def mod
      @mod  
    end
    def run
      @obj = @clazz.new(*@args)
      @ctx.call(self,&@blk) if @blk
      @obj
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
  end #TypeBuilder

  class CherifyBuilder  < Cheri::Builder::AbstractBuilder
    def initialize(mod,ctx,sym,*args,&k)
      raise Cheri.argument_error(args.length,1) unless args.length == 1
      super(ctx,sym,*args,&k)
      @mod = mod
      @obj = args.first
    end
    def mod
      @mod    
    end
    def run
      @ctx.call(self,&@blk) if @blk
      @obj
    end
  end

  class CheriYieldBuilder < CherifyBuilder
    def child?
      false    
    end  
  end

  class TypeFactory
    def initialize(mod,types)
      raise Cheri.type_error(types,BuildTypes) unless BuildTypes === types
      @mod = mod
      @types = types
      @inv = types.invert
    end
    def builder(ctx,sym,*r,&k)
      if (type = @types[sym])
        TypeBuilder.new(@mod,type,ctx,sym,*r,&k)
      elsif @inv[r.first.class]
        if sym == :cherify
          CherifyBuilder.new(@mod,ctx,sym,*r,&k)
        elsif sym == :cheri_yield
          CheriYieldBuilder.new(@mod,ctx,sym,*r,&k)
        else
          nil
        end
      else
        nil
      end
    end
  end #TypeFactory

  # Factory for self-building types (e.g., Cheri markup types)
  class AutoFactory
    def initialize(mod,types)
      raise Cheri.type_error(types,BuildTypes) unless BuildTypes === types
      @mod = mod
      @types = types
      @inv = types.invert
    end
    def builder(ctx,sym,*r,&k)
      if (type = @types[sym])
        bld = type.clazz.new(ctx,sym,*r,&k)
      elsif @inv[r.first.class]
        if sym == :cherify
          CherifyBuilder.new(@mod,ctx,sym,*r,&k)
        elsif sym == :cheri_yield
          CheriYieldBuilder.new(@mod,ctx,sym,*r,&k)
        else
          nil
        end
      else
        nil
      end
    end
  end #AutoFactory

  CamelCase = /([a-z])([A-Z])/ #:nodoc:
  RubyCase = '\1_\2' #:nodoc:
  Sep = '::' #:nodoc:
  def initialize(*r,&k)
    raise ArgumentError,"no args or block supplied" unless k || !r.empty?
    raise ArgumentError,"no arguments permitted when block supplied" if k && !r.empty?
    @args = r
    @blk = k if k
  end
  
  def run
    if @blk
      eb = EvalBuilder.new(&@blk)
      create_mod(eb)
    else
      # _really_ simple builder
      @types = BuildTypes.new
      @ctr = TypeConnecter.new
      if Hash === @args.last
        @args.pop.each_pair do |clazz,adder|
          add_type(clazz,nil,adder)        
        end      
      end
      @args.each do |clazz|
        add_type(clazz)
      end
      create_simple_mod
    end
  end

  def add_type(clazz,sym=nil,adder=:add)
    raise Cheri.type_error(clazz,Class) unless Class === clazz
    raise Cheri.type_error(sym,Symbol,String) if sym && !(Symbol === sym || String === sym)
    raise Cheri.type_error(adder,Symbol,String) unless Symbol === adder || String === adder
    sym ||= make_sym(clazz)
    adder = adder.to_sym
    warn "warning: redefining type #{sym} => #{clazz}" if @types[sym]
    @types[sym] = BuildType.new(clazz,sym)
    @ctr.add_type(clazz).connect(Object,adder)
  end
  private :add_type

  def make_sym(clazz)
    if (s = (name = clazz.name).rindex(Sep))
      name = name[s+2,name.length-s-2]      
    end
    name.gsub(CamelCase,RubyCase).downcase!.to_sym
  end
  private :make_sym
    
  def create_simple_mod
    mod = Template.dup
    mod.instance_variable_set(:@fct, fct = TypeFactory.new(mod,@types))
    mod.const_set('Factory',fct)
    mod.instance_variable_set(:@ctr,@ctr)
    mod.const_set('Connecter',@ctr)
    mod.instance_variable_set(:@cns,Cheri::Builder::DefaultConsumer)
    mod.const_set('Consumer',Cheri::Builder::DefaultConsumer)
    mod.send(:include,Cheri::Builder)
    mod
  end
  private :create_simple_mod
  
  def create_mod(eb)
    mapped = eb.__mapped
    unmapped = eb.__unmapped
    ext = eb.__ext
    pkg = eb.__pkg
    tc = eb.__tc
#    sc = eb.__sc
    # this may be valid if the user is just adding connecters to an existing builder
    if mapped.empty? && unmapped.empty? && !pkg && !(ext && tc)
      raise BuilderException,"no build classes specified!"
    end
    # map any unmapped class names to symbols 
    unless unmapped.empty?
      iv = mapped.invert
      unmapped.each do |unm|
        unless iv[unm.clazz]
          sym = make_sym(unm.clazz)
          if (dupl = mapped[sym])
            warn "warning: derived symbol #{sym} (#{unm}) conflicts with symbol for #{dupl} -- ignoring"
          else
            mapped[sym] = unm
          end
        end
      end
    end

    # separate the Java classes (if any)
    jmapped = nil
    if !mapped.empty? && defined?Cheri::Java::Builder
      jmapped = BuildTypes.new
      mapped.each_pair do |sym,type|
        jmapped[sym] = type if type.clazz.respond_to?(:java_class)
      end
      if jmapped.empty?
        jmapped = nil        
      else
        jmapped.each_key do |sym|
          mapped.delete(sym)
        end
      end
    end
      
    # separate the auto classes (self-building, e.g. Cheri::Xml::Elem), if any
    # doesn't (currently) apply to Java classes (and likely never will)
    amapped = nil
    unless mapped.empty?
      amapped = BuildTypes.new
      mapped.each_pair do |sym,type|
        amapped[sym] = type if type.clazz < Cheri::Builder::Frame
      end
      if amapped.empty?
        amapped = nil
      else
        amapped.each_key do |sym|
          mapped.delete(sym)
        end
      end
    end
      
    mapped = nil if mapped.empty?
      
    # create the module
    mod = Template.dup
    mod.send(:include,Cheri::Builder)
    # determine if we need a SuperFactory
    fcount = 0
    fcount += 1 if mapped
    fcount += 1 if jmapped
    fcount += 1 if amapped
    fcount += pkg.length if pkg
      
    # setup the factory(s)
    if fcount > 1
      fct = SuperFactory.new do |f|
        f << TypeFactory.new(mod,mapped) if mapped
        f << AutoFactory.new(mod,amapped) if amapped
        f << Cheri::Java::Builder::GenericBuilderFactory.new(mod,jmapped) if jmapped
        pkg.each do |p|
          f << Cheri::Java::Builder::PackageFactory.new(p,mod)
        end if pkg
      end
    elsif mapped
      fct = TypeFactory.new(mod,mapped)
    elsif amapped
      fct = AutoFactory.new(mod,amapped)
    elsif jmapped
      fct = Cheri::Java::Builder::GenericBuilderFactory.new(mod,jmapped)
    elsif pkg
      fct = Cheri::Java::Builder::PackageFactory.new(pkg.first,mod)
    else
      fct = nil
    end
    if fct
      mod.instance_variable_set(:@fct,fct)
      mod.const_set('Factory',fct)
    end

    # setup connecter
    if tc
      mod.instance_variable_set(:@ctr,tc)
      mod.const_set('Connecter',tc)
    end
      
    # setup consumers - TODO: pkg builders?
    if mapped || amapped || jmapped
      if (amapped || mapped) && jmapped
        cns = SuperConsumer[Cheri::Java::Builder::DefaultConsumer,Cheri::Builder::DefaultConsumer]
      elsif amapped || mapped
        cns = Cheri::Builder::DefaultConsumer
      else
        cns = Cheri::Java::Builder::DefaultConsumer
      end
      mod.instance_variable_set(:@cns,cns)
      mod.const_set('Consumer',cns)
    end

    # setup extend builder, if any
    ext ||= Cheri::Java::Builder if jmapped || pkg
    if ext
      mod.instance_variable_set(:@ext,ext)
      mod.module_eval do
        def self.extends
          @ext
        end        
      end
    end
    mod
  end
  private :create_mod

  class EvalBuilder

    def initialize(*r,&k)
      @__mapped = BuildTypes.new
      @__unmapped = []
      instance_eval(&k)  
    end

    def __mapped
      @__mapped  
    end
  
    def __unmapped
      @__unmapped
    end
  
    def __ext
      @__ext  
    end
  
    def __pkg
      @__pkg
    end
  
    def __tc
      @__tc  
    end
  
    def extend_builder(bld)
      return unless bld
      raise BuilderException,"only one extend_builder may be specified" if @__ext
      unless bld.respond_to?(:factory) || bld.respond_to?(:connecter) ||
          bld.respond_to?(:consumer) || bld.respond_to?(:resolver)
        raise ArgumentError,"not a valid builder: #{bld}"
      end
      @__ext = bld
    end

    def build(type,sym=nil,&k)
      raise Cheri.type_error(type,Class) unless Class === type
      if sym
        if Symbol === sym
          add_mapped(type,sym,&k)
        elsif Array === sym
          sym.each do |s|
            raise Cheri.type_error(s,Symbol) unless Symbol === s
            add_mapped(type,s,&k)        
          end
        else
          raise Cheri.type_error(sym,Symbol,Array)
        end
      else
        @__unmapped << BuildType.new(type,nil,&k) unless @__unmapped.include?(type) 
      end
    end
  
    def add_mapped(type,sym,&k)
      warn "warning: redefining :#{sym} from #{@__mapped[sym]} to #{type}" if @__mapped[sym]
      @__mapped[sym] = BuildType.new(type,sym,&k)
    end
    private :add_mapped
 
    def build_package(str)
      raise Cheri.type_error(str,String) unless String === str
      raise BuilderException,"packages supported only for Java (JRuby)" unless defined?JRUBY_VERSION
      require 'cheri/java/builder'
      if @__pkg
        @__pkg << str unless @__pkg.include?(str)
      else
        @__pkg = [str]    
      end
    end
  
    def type(mod,&k)
      @__tc ||= TypeConnecter.new
      @__tc.type(mod,&k)  
    end
    alias_method :types, :type
    alias_method :symbol, :type
    alias_method :symbols, :type
  
 
  end #EvalBuilder

end #Generator

end #Builder
end #Cheri
