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

class TypeConnecter

  def initialize(*parents,&block)
    @t = {}
    @s = {}
    @c = {}
    parents.each do |parent| merge!(parent); end
    instance_eval(&block) if block
  end
  
  def merge!(other)
    raise Cheri.type_error(other,TypeConnecter) unless TypeConnecter === other
    t = @t
    s = @s
    other.get_types.each_pair do |mod,type|
      if (tmod = t[mod])
        tmod.merge(type)
      else
        t[mod] = type.copy
      end
    end
    other.get_syms.each_pair do |sym,symc|
      if (ssym = s[sym])
        ssym.merge(symc)
      else
        s[sym] = symc.copy
      end
    end
    self
  end

  def prepare(ctx,builder,obj,sym,props)
    # try parent symbol matches first
    if (ssym = @s[builder.sym])
      # child symbol match?
      if (sctr = ssym.sctrs[sym])
        return sctr.prepare(ctx,builder,obj,sym,props) 
      end
      # child type match?
      unless ssym.tctrs.empty?
        anc = (class<<obj;self;end).ancestors
        ix = anc.length
        match = nil
        # match on nearest ancestor
        ssym.tctrs.each do |tctr|
          if (cix = anc.index(tctr.mod)) && cix < ix
            ix = cix
            match = tctr
          end
        end
        return match.prepare(ctx,builder,obj,sym,props) if match
      end
    end
    # then try parent type matches
    t = @t
    bld_anc = (class<<builder.object;self;end).ancestors
    anc ||= (class<<obj;self;end).ancestors
    key = [sym,bld_anc,anc]
    if (ctr = @c[key])
      return ctr.prepare(ctx,builder,obj,sym,props)
    end
    bld_anc.each do |a|
      if (type = t[a])
        # child symbol match?
        if (sctr = type.sctrs[sym])
          @c[key] = sctr
          return sctr.prepare(ctx,builder,obj,sym,props) 
        end
        # child type match?
        #anc ||= (class<<obj;self;end).ancestors
        ix ||= anc.length
        match = nil
        # match on nearest ancestor
        type.tctrs.each do |tctr|
          if (cix = anc.index(tctr.mod)) && cix < ix
            ix = cix
            match = tctr
          end
        end
        if match
          @c[key] = match
          return match.prepare(ctx,builder,obj,sym,props)
        end
      end
    end
    false
  end

  def type(mod,&k)
    if Module === mod
      tp = @t[mod] ||= Type.new(mod)
      tp.instance_eval(&k) if k
    elsif Symbol === mod
      sm = @s[mod] ||= Sym.new(mod)
      sm.instance_eval(&k) if k
    elsif Array === mod
      mod.each do |m|
        if Symbol === m
          sm = @s[m] ||= Sym.new(m)
          sm.instance_eval(&k) if k
        elsif Module === m
          tp = @t[m] ||= Type.new(m)
          tp.instance_eval(&k) if k
        else
          raise Cheri.type_error(m,Symbol,Class,Module)
        end
      end    
    else
      raise Cheri.type_error(mod,Class,Module,Symbol,Array)
    end
    nil
  end
  alias_method :types, :type
  alias_method :symbol, :type
  alias_method :symbols, :type

  def get_types
    @t
  end
  protected :get_types

  def get_syms
    @s
  end
  protected :get_syms

  # used by simple builder-builder
  def add_type(mod) #:nodoc:
    @t[mod] ||= Type.new(mod)
  end
  

  class Type
    def initialize(mod)
      raise Cheri.type_error(mod,Class,Module) unless Module === mod
      @m = mod
      @t = []
      @s = {}
    end

    def connect(mod,adder=nil,&k)
      raise Cheri.type_error(adder,Symbol) if adder && !(Symbol === adder)
      adder ||= :add unless k
      if Module === mod
        addm(mod,adder,&k)
      elsif Symbol === mod
        adds(mod,adder,&k)      
      elsif Array === mod
        mod.each do |m|
          if Module === m
            addm(m,adder,&k)
          elsif Symbol === m
            adds(m,adder,&k)
          else
            raise Cheri.type_error(m,Class,Module,Symbol)
          end
        end
      else
        raise Cheri.type_error(mod,Class,Module,Symbol,Array)
      end
      nil
    end
    
    def addm(mod,adder,&k)
      ctr = TCtr.new(mod,adder,&k)
      @t.delete mod
      @t << ctr
    end
    private :addm

    def adds(sym,adder,&k)
      @s[sym] = SCtr.new(sym,adder,&k)
    end
    private :adds

    def mod
      @m
    end

    def tctrs
      @t  
    end
    
    def sctrs
      @s    
    end
    
    def merge(other)
      raise Cheri.type_error(other,Type) unless Type === other
      t = @t
      other.tctrs.each do |tctr| t.delete(tctr.mod); end
      t.concat(other.tctrs)
      s = @s
      other.sctrs.each do |sctr| s[sctr.sym] = sctr; end
      nil
    end

    def copy
      self.class.allocate.copy_from(@m,@t,@s)    
    end
    
    def copy_from(mod,tctrs,sctrs)
      @m = mod
      @t = tctrs.dup
      @s = sctrs.dup
      self
    end
    protected :copy_from

  end #Type

  class Sym
    def initialize(sym)
      raise Cheri.type_error(sym,Symbol) unless Symbol === sym
      @m = sym
      @t = []
      @s = {}
    end

    def connect(sym,adder=nil,&k)
      raise Cheri.type_error(adder,Symbol) if adder && !(Symbol === adder)
      adder ||= :add unless k
      if Symbol === sym
        adds(sym,adder,&k)      
      elsif Module === sym
        addm(sym,adder,&k)
      elsif Array === sym
        sym.each do |m|
          if Symbol === m
            adds(m,adder,&k)
          elsif Module === m
            addm(m,adder,&k)
          else
            raise Cheri.type_error(m,Symbol,Class,Module)
          end
        end
      else
        raise Cheri.type_error(sym,Symbol,Class,Module,Array)
      end
      nil
    end
    
    def addm(mod,adder,&k)
      ctr = TCtr.new(mod,adder,&k)
      @t.delete mod
      @t << ctr
    end
    private :addm

    def adds(sym,adder,&k)
      @s[sym] = SCtr.new(sym,adder,&k)
    end
    private :adds

    def sym
      @m
    end

    def tctrs
      @t  
    end
    
    def sctrs
      @s    
    end
    
    def merge(other)
      raise Cheri.type_error(other,Sym) unless Sym === other
      t = @t
      other.tctrs.each do |tctr| t.delete(tctr.mod); end
      t.concat(other.tctrs)
      s = @s
      other.sctrs.each do |sctr| s[sctr.sym] = sctr; end
      nil
    end

    def copy
      self.class.allocate.copy_from(@m,@t,@s)    
    end
    
    def copy_from(sym,tctrs,sctrs)
      @m = sym
      @t = tctrs.dup
      @s = sctrs.dup
      self
    end
    protected :copy_from

  end #Sym

  class TCtr #:nodoc: all
    def initialize(mod,adder=nil,&k)
      raise Cheri.type_error(mod,Class,Module) unless Module === mod
      raise Cheri.type_error(adder,Symbol) if adder && !(Symbol === adder)
      @m = mod
      @a = adder if adder
      @k = k if k
    end

    def mod
      @m
    end

    def ==(other)
      TCtr === other ? @m == other.mod : @m == other      
    end
      
    def eql?(other)
      TCtr === other ? @m.eql?(other.mod) : @m.eql?(other)
    end
      
    def <=>(other)
      @m.name <=> other.mod.name      
    end

    def prepare(ctx,builder,obj,sym,props)
      ctx.ppd(self,builder,obj,(@a || sym),props)
    end

    def connect(parent,obj,sym,props)
      if @k
        @k.call(parent,obj,sym,props)
      else
        parent.__send__(sym,obj) #rescue nil
      end
      nil
    end
  end #TCtr

  class SCtr #:nodoc: all
    def initialize(sym,adder=nil,&k)
      raise Cheri.type_error(sym,Symbol) unless Symbol === sym
      raise Cheri.type_error(adder,Symbol) if adder && !(Symbol === adder)
      @m = sym
      @a = adder if adder
      @k = k if k
    end

    def sym
      @m
    end

    def ==(other)
      SCtr === other ? @m == other.sym : @m == other      
    end
      
    def eql?(other)
      SCtr === other ? @m.eql?(other.sym) : @m.eql?(other)
    end
      
    def <=>(other)
      @m.to_s <=> other.sym.to_s      
    end

    def prepare(ctx,builder,obj,sym,props)
      ctx.ppd(self,builder,obj,(@a || sym),props)
    end

    def connect(parent,obj,sym,props)
      if @k
        @k.call(parent,obj,sym,props)
      else
        parent.__send__(sym,obj) #rescue nil
      end
      nil
    end
  end #SCtr

end #TypeConnecter

end #Builder
end #Cheri
