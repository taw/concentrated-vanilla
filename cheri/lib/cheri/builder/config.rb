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

class Config
  None = {}.freeze #:nodoc:
  def initialize(*mods)
    @m = [] # included modules
    @f = {} # factories, indexed by module
    @c = {} # connecters, indexed by module
    @n = {} # consumers, indexed by module
    # @r = {} # resolvers, indexed by module
    mods.each do |mod| self << mod; end
  end

  def mods
    @m
  end

  def factories
    @f
  end

  def connecters
    @c
  end

  def consumers
    @n
  end

  
  # FIXME: eliminate!
  def resolvers
    @r || None
  end

  def <<(mod)
    return if @m.include?(mod)
    validate(mod) unless mod == Cheri::Builder
    extendee = mod.respond_to?(:extends) ? mod.extends : nil
    raise BuilderException,"extended builder module not included: #{extendee}" if extendee && !@m.include?(extendee)
    @m << mod

    if mod.respond_to?(:factory) && (obj = mod.factory)
      @f[mod] = obj
    end
    
    if mod.respond_to?(:connecter) && (obj = mod.connecter)
      @c[mod] = obj
    end

    if mod.respond_to?(:consumer) && (obj = mod.consumer)
      @n[mod] = obj
    end
    
    # FIXME: eliminate (isolate in Java class stuff)
    (@r ||= {})[mod] = mod.resolver if mod.respond_to?(:resolver) && mod.resolver


    extend_mod(extendee,mod) if extendee
    self
  end
  alias_method :add, :<<

  def flatten(obj)
    if obj
      if Aggregate === obj
        obj.flatten
      else
        [obj]      
      end
    else
      []    
    end
  end
  private :flatten

  def merge_aggregates(amod, aext, aggr_clazz)
    aggr = aggr_clazz.new
    flatten(aext).each do |elem|
      aggr << elem      
    end
    flatten(amod).each do |elem|
      aggr << elem      
    end
    aggr    
  end
  private :merge_aggregates
  
  def merge_factories(fmod, fext)
    merge_aggregates(fmod,fext,SuperFactory)  
  end
  private :merge_factories
  
  def merge_consumers(cmod, cext)
    merge_aggregates(cmod,cext,SuperConsumer)  
  end
  private :merge_consumers

  def merge_connecters(cmod, cext)
    # first, break down connecters into TypeConnecters and others
    tcs = []
    others = []
    flatten(cmod).each do |ctr|
      if TypeConnecter === ctr
        tcs << ctr
      else
        others << ctr      
      end    
    end
    # we want extender's TC's after mod's
    (fext = flatten(cext)).each do |ctr|
      tcs << ctr if TypeConnecter === ctr
    end
    # we want extender's other connecters before mod's
    fext.reverse_each do |ctr|
      others.unshift(ctr) unless TypeConnecter === ctr
    end
    
    # combine (merge) any TypeConnecters
    unless tcs.empty?
      tc = TypeConnecter.new
      tcs.each do |atc|
        tc.merge!(atc)
      end
      # return the merged TC if there are no other
      # connecters (the usual case)
      return tc if others.empty?   
    else
      tc = nil
    end
    
    # aggregate any 'other' (non-TypeConnecter) connecters, 
    # and add the (merged) TypeConnecter (if any) last
    sc = SuperConnecter.new
    others.each do |oth|
      sc << oth      
    end
    sc << tc if tc
    sc
  end
  private :merge_connecters
  
  def extend_mod(mod,ext)
    # get to the base module to be extended
    while mod.respond_to?(:extends) && (mext = mod.extends)
      mod = mext
    end
    
    # merge the extendee's (mod) factory(s) with the extender's (ext)
    # factory(s).  update any reference to either to point to the 
    # merged factory(s).
    mods = [mod,ext]
    hash = @f
    hmod = hash[mod]
    hext = hash[ext]
    hash.each_pair do |m,h|
      mods << m if h == hmod || h == hext unless mods.include?(m) 
    end    
    merged = merge_factories(hmod,hext)
    mods.each do |m|
      hash[m] = merged
    end

    # merge the extendee's (mod) connecter(s) with the extender's (ext)
    # connecter(s).  update any reference to either to point to the 
    # merged connecter(s).
    mods = [mod,ext]
    hash = @c
    hmod = hash[mod]
    hext = hash[ext]
    hash.each_pair do |m,h|
      mods << m if h == hmod || h == hext unless mods.include?(m)
    end    
    merged = merge_connecters(hmod,hext)
    mods.each do |m|
      hash[m] = merged
    end

    # merge the extendee's (mod) consumers(s) with the extender's (ext)
    # consumers(s).  update any reference to either to point to the 
    # merged consumer(s).
    mods = [mod,ext]
    hash = @n
    hmod = hash[mod]
    hext = hash[ext]
    hash.each_pair do |m,h|
      mods << m if h == hmod || h == hext unless mods.include?(m)
    end    
    merged = merge_consumers(hmod,hext)
    mods.each do |m|
      hash[m] = merged
    end
  end
  private :extend_mod
  
  def include?(mod)
    @m.include?(mod)
  end

  def each
    @m.each_key {|m| yield m } if block_given?
  end
  
  def copy
    self.class.allocate.copy_from(@m,@f,@c,@n,@r)
  end

  # Overrides the default Object#inspect to prevent mind-boggling circular displays in IRB.
  def inspect
    to_s
  end

protected
  def copy_from(m,f,c,n,r)
    @m = m.dup
    @f = f.dup
    @c = c.dup
    @n = n.dup
    @r = r.dup if r
    self
  end  
private
  def validate(mod)
    functional = nil
    if mod.respond_to?(:factory) && (obj = mod.factory)
      raise validate_error(mod,'invalid factory') unless obj.respond_to?(:builder)
      functional = true
    end
    if mod.respond_to?(:connecter) && (obj = mod.connecter)
      raise validate_error(mod,'invalid connecter') unless obj.respond_to?(:prepare)
      functional = true
    end  
    if mod.respond_to?(:consumer) && (obj = mod.consumer)
      raise validate_error(mod,'invalid consumer') unless obj.respond_to?(:consume)
      functional = true
    end
    if mod.respond_to?(:resolver) && (obj = mod.resolver)
      raise validate_error(mod,'invalid resolver') unless obj.respond_to?(:resolve_ctor) &&
                                                          obj.respond_to?(:resolve_meth)
      functional = true
    end
    raise validate_error(mod,'no functionality') unless functional
    true
  end
  def validate_error(mod,reason)
    BuilderException.new("not a valid builder module: #{mod} (#{reason})")  
  end

end #Config

end #Builder
end #Cheri
