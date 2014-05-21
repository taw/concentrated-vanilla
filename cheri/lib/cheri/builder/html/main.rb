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
module Html

include Cheri::Builder

class << self
  def append_features(clazz)
    Cheri::Builder.module_included(self,clazz)
    super
  end
  private :append_features

  def factory
    HtmlFactory  
  end

  def connecter
    HtmlConnecter  
  end  

end #self

  # Instance methods

  # call-seq:
  #   html([*args] [, &block]) -> HtmlProxy if no block given, else result of block
  #   
  def html(*r,&k)
    if ctx = __cheri_ctx
      unless copts = ctx[:html_opts]
        iopts = ctx.ictx[:html_opts] ||= HtmlOptions.new
        copts = ctx[:html_opts] = HtmlOptions.new(iopts)
      end
      if k
        if ctx.tos(HtmlElement)
          HtmlFrame.new(ctx,*r,&k).run
        else
          if r.empty?
            ctx.msend(Cheri::Html,:html,&k)
          else
            copts.ingest_args(*r)
            if args = copts.delete(:args)
              ctx.msend(Cheri::Html,:html,args,&k)
            else
              ctx.msend(Cheri::Html,:html,&k)
            end
          end
        end
      else
        unless r.empty?
          copts.ingest_args(*r)
          copts.delete(:args)
        end
        ctx[:html_proxy] ||= HtmlProxy.new(ctx,*r)
      end
    end
  end
  private :html


module HtmlFactory
  def self.builder(ctx,sym,*r,&k)
    opts = ctx[:html_opts] || {}
    if ((als = opts[:alias]) && (asym = als[sym])) || (asym = Aliases[sym])
      sym = asym
    end
    clazz = Types[sym]
    clazz ? clazz.new(ctx,sym,*r,&k) : nil
  end
end #HtmlFactory

class HtmlOptions < Cheri::Builder::BaseOptions
  def validate(key,value)
    raise Cheri.type_error(key,Symbol) unless Symbol === key
    case key
      when :esc : validate_boolean_nil(value) || nil
      when :doctype : validate_boolean_nil(value) || nil
      when :strict : validate_boolean_nil(value) || nil
      when :validate : validate_boolean_nil(value) || nil
      when :warn : validate_boolean_nil(value) || nil
      when :raise : validate_boolean_nil(value) || nil
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
      # anything else gets passed through as args to html
      args = self[:args] ||= {}
      args[key] = value
      nil
    end
  end
end #HtmlOptions

class HtmlProxy < Cheri::Builder::BaseProxy

  impl(Types.keys)
  
  def mod
    Cheri::Html  
  end
  private :mod

  def [](*args)
    ictx = (ctx = @ctx).ictx
    iopts = ictx[:html_opts] ||= HtmlOptions.new
    iopts.ingest_args(*args)
    iopts.delete(:args)
    copts = ctx[:html_opts] ||= HtmlOptions.new
    copts.ingest_args(*args)
    copts.delete(:args)
    nil
  end
end #HtmlProxy

class HtmlFrame
  include Cheri::Builder::Frame
  def initialize(ctx,*r,&k)
    super(ctx,&k)
    @obj = ctx[:html_proxy] ||= HtmlProxy.new(ctx,*r)  
    @args = r unless r.empty?
   end
  def mod
    Cheri::Html  
  end
  def run
    if blk = @blk
      if args = @args
        opts = (ctx = @ctx)[:html_opts]
        temp = HtmlOptions.new(opts)
        temp.ingest_args(*args)
        ctx[:html_opts] = temp
        result = ctx.call(self,&blk)
        ctx[:html_opts] = opts
        result
      else
        @ctx.call(self,&blk)
      end
    end
  end
end #HtmlFrame

end #Html
end #Cheri
