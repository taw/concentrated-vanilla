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
module Xml

include Cheri::Builder

class << self
  def append_features(clazz)
    Cheri::Builder.module_included(self,clazz)
    super
  end
  private :append_features

  def factory
    XmlFactory  
  end

  def connecter
    XmlConnecter  
  end

end #self

  # Instance methods

  # call-seq:
  #   xml([*args] [, &block]) -> XmlProxy if no block given, else result of block
  #   
  def xml(*r,&k)
    if ctx = __cheri_ctx
      unless copts = ctx[:xml_opts]
        iopts = ctx.ictx[:xml_opts] ||= XmlOptions.new
        copts = ctx[:xml_opts] = XmlOptions.new(iopts)
      end
      if k      
        if ctx.tos(XmlBuilder)
          XmlFrame.new(ctx,*r,&k).run
        else
          copts.ingest_args(*r) unless r.empty?
          ctx.msend(Cheri::Xml,:xml,&k)
        end
      else
        copts.ingest_args(*r) unless r.empty?
        ctx[:xml_proxy] ||= XmlProxy.new(ctx,*r)
      end
    end
  end
  private :xml
  
module XmlFactory
  def self.builder(ctx,sym,*r,&k)
    opts = ctx[:xml_opts] || {}
    if ((als = opts[:alias]) && (asym = als[sym])) || (asym = Aliases[sym])
      sym = asym
    end
    if (clazz = Types[sym])
      clazz.new(ctx,sym,*r,&k)
    elsif :no_ns == sym || ((hns = opts[:ns]) && hns[sym])
      ns = (ctx[:xml_ns] ||= {})[sym] ||= Namespace.new(ctx,sym)
      NamespaceBuilder.new(ns,ctx,sym,*r,&k)
    elsif opts[:any] || ((acc = opts[:accept]) && acc[sym])
      Elem.new(ctx,sym,*r,&k)
    else
      nil
    end
  end
end #XmlFactory

class XmlOptions < Cheri::Builder::BaseOptions
  def validate(key,value)
    raise Cheri.type_error(key,Symbol) unless Symbol === key
    case key
      when :any : validate_boolean_nil(value) || nil
      when :esc : validate_boolean_nil(value) || nil
      when :format : validate_boolean_nil(value) || nil
      when :indent
        unless Fixnum === value
          if true == value
            value = 2
          elsif false == value || nil == value
            value = nil
          else
            raise Cheri.type_error(value,Fixnum,TrueClass,FalseClass,NilClass)
          end
        end
        store(:format,true) if value
        value
      when :margin
        unless Fixnum === value
          if false == value || nil == value
            value = nil
          else
            raise Cheri.type_error(value,Fixnum,FalseClass,NilClass)
          end
        end
        store(:format,true) if value
        value
      when :ns
        value = value.to_sym if String === value
        if Symbol === value
          hns = self[:ns] || {}
          hns[value] = true
          hns
        elsif Array === value
          hns = self[:ns] || {}
          value.each do |ns|
            if String === ns
              ns = ns.to_sym
            else
              validate_symbol(ns)
            end
            hns[ns] = true
          end
          warn "warning: empty array specified in xml :ns" if value.empty?
          hns
        elsif Hash === value
          value.each_pair do |k,v|
            validate_symbol(k)
            validate_boolean_nil(v)
          end
          value
        else
          raise Cheri.type_error(value,Symbol,Array,Hash)
        end
      when :accept
        value = value.to_sym if String === value
        if Symbol === value
          acc = self[:accept] || {}
          acc[value] = true
          acc
        elsif Array === value
          acc = self[:accept] || {}
          value.each do |a|
            if String === a
              a = a.to_sym
            else
              validate_symbol(a)
            end
            acc[a] = true
          end
          warn "warning: empty array specified in xml :accept" if value.empty?
          store(:any,false)
          acc
        elsif Hash === value
          value.each_pair do |k,v|
            validate_symbol(k)
            validate_boolean_nil(v)
          end
          value
        else
          raise Cheri.type_error(value,Symbol,Array,Hash)
        end
      when :alias
        if Array === value
          raise ArgumentError,"odd number of values for :alias" if ((len = value.length) & 1) == 1
          als = self[:alias] || {}
          (len>>1).times do |i|
            als[value[i*2].to_sym] = value[i*2+1].to_sym
          end
          als
        elsif Hash === value
          value.each_pair do |k,v|
            validate_symbol(k)
            validate_symbol(v)
          end
          value
        else
          raise Cheri.type_error(value,Array,Hash)
        end
      when :attr
        if Array === value
          raise ArgumentError,"odd number of values for :attr" if ((len = value.length) & 1) == 1
          als = self[:attr] || {}
          (len>>1).times do |i|
            als[value[i*2].to_sym] = value[i*2+1].to_sym
          end
          als
        elsif Hash === value
          value.each_pair do |k,v|
            validate_symbol(k)
            validate_symbol(v)
          end
          value
        else
          raise Cheri.type_error(value,Array,Hash)
        end
    else
      raise ArgumentError,"invalid xml option: #{key}"
    end
  end
end #XmlOptions


class XmlProxy < Cheri::Builder::BaseProxy

  impl(Types.keys)
  
  def mod
    Cheri::Xml  
  end
  private :mod
  
  def [](*args)
    ictx = (ctx = @ctx).ictx
    iopts = ictx[:xml_opts] ||= XmlOptions.new
    iopts.ingest_args(*args)
    copts = ctx[:xml_opts] ||= XmlOptions.new
    copts.ingest_args(*args)
    nil
  end

end #XmlProxy

class NamespaceBuilder
  include Cheri::Builder::Builder
  def initialize(ns,*r,&k)
    super(*r,&k)
    @obj = ns
  end
  def child?
    false
  end
  def parent?
    false  
  end
  def any?
    true
  end
  def mod
    Cheri::Xml  
  end
end #NamespaceBuilder

class XmlFrame
  include Cheri::Builder::Frame
  def initialize(ctx,*r,&k)
    super(ctx,&k)
    @obj = ctx[:xml_proxy] ||= XmlProxy.new(ctx,*r)
    @args = r unless r.empty?
  end
  def mod
    Cheri::Xml  
  end
  def run
    if blk = @blk
      if args = @args
        opts = (ctx = @ctx)[:xml_opts]
        temp = XmlOptions.new(opts)
        temp.ingest_args(*args)
        ctx[:xml_opts] = temp
        result = ctx.call(self,&blk)
        ctx[:xml_opts] = opts
        result
      else
        @ctx.call(self,&blk)
      end
    end
  end
end #XmlFrame

end #Xml
end #Cheri
