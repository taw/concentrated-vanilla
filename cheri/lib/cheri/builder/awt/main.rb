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
# TODO: module comments
module AWT
VERSION = Cheri::VERSION

include Cheri::Builder

CJava = Cheri::Java #:nodoc:
CBuilder = Cheri::Builder #:nodoc:
JBuilder = Cheri::Java::Builder #:nodoc:
class << self
  def append_features(clazz)
    CBuilder.module_included(JBuilder,clazz)
    CBuilder.module_included(self,clazz)
    super
  end
  private :append_features
  
  def factory
    AWTFactory  
  end
  
  def connecter
    AWTConnecter  
  end

  def consumer
    AWTConsumer
  end
  
  def resolver
    AWTResolver  
  end

  # call-seq:
  #   mod.prepare(context, parent, object, sym, properties=nil) -> prepared?
  # 
#  def prepare(*r)
#    AWTConnecter.prepare(*r)
#  end
  
end #self


  # call-seq:
  #   awt([*args] [, &block]) -> AWTProxy if no block given, else result of block
  #   
  def awt(*r,&k)
    if ctx = __cheri_ctx
      if k
        AWTFrame.new(ctx,*r,&k).run
      else
        ctx[:awt_proxy] ||= AWTProxy.new(ctx,*r)
      end
    end
  end
  private :awt


class AWTClassBuilder < Cheri::Java::Builder::ClassBuilder
Frame = CJava.get_class('java.awt.Frame')
  def mod
    Cheri::AWT  
  end
private
  def post
    @obj.icon_image ||= CJava.cheri_icon.image if @obj.kind_of?(Frame)
  end
end

module StandardFactory
  T = Cheri::AWT::Types #:nodoc:
  def self.builder(ctx,sym,*r,&k)
    clazz = T.get_class(sym)
    clazz ? AWTClassBuilder.new(ctx,sym,clazz,*r,&k) : nil
  end
end #AWTFactory

AWTFactory = Cheri::Builder::SuperFactory.new do |f|
  f << StandardFactory
  f << Cheri::Java::Builder::CheriYieldFactory
  f << Cheri::Java::Builder::CherifyFactory
  f << Cheri::Builder::CheriYieldFactory
  f << Cheri::Builder::CherifyFactory
end

class AWTProxy < Cheri::Builder::BaseProxy

  impl(Types.names)

  def initialize(ctx,*r)
    super
    if Hash === r.last
      @ctx.auto!(mod) if r.last[:auto]
    end  
  end

  def mod
    Cheri::AWT  
  end
  private :mod

  def [](opts)
    raise Cheri.type_error(opts,Hash) unless Hash === opts
    if opts[:auto]
      @ctx.ictx.auto!(mod)
      @ctx.auto!(mod)
    end
    self
  end
end #AWTProxy

class AWTFrame
  include Cheri::Builder::Frame
  def initialize(ctx,*r,&k)
    super
    @obj = ctx[:awt_proxy] ||= AWTProxy.new(ctx,*r)  
  end
  def mod
    Cheri::AWT  
  end
end #AWTFrame

module SizeMethodConsumer
#:stopdoc:
Meths = {
  :minimum_size => :minimum_size=,
  :set_minimum_size => :minimum_size=,
  :maximum_size => :maximum_size=,
  :set_maximum_size => :maximum_size=,
  :preferred_size => :preferred_size=,
  :set_preferred_size => :preferred_size=,
  :fixed_size => true
}.freeze
Cmp = ::Java::JavaAwt::Component
Dim = ::Java::JavaAwt::Dimension
#:startdoc:
  def self.consume(ctx,bld,sym,*args,&block)
    return false,nil unless (meth = Meths[sym]) && args.length == 2 && 
      Cmp === (obj = bld.object) && Fixnum === (w = args[0]) && Fixnum === (h = args[1])
    dim = Dim.new w,h
    if :fixed_size == sym
      obj.minimum_size = dim
      obj.maximum_size = dim
      obj.preferred_size = dim
    else
      obj.__send__(meth,dim)
    end
    return true, nil
  end
end

AWTConsumer = Cheri::Builder::SuperConsumer.new do |c|
  c << SizeMethodConsumer
  c << Cheri::Java::Builder::EventMethodConsumer
  c << Cheri::Java::Builder::GenericConsumer
  c << Cheri::Builder::DefaultConsumer
end

AWTResolver = Cheri::Java::Builder::ConstantResolver.new do |r|
  r << Constants
end


end #AWT
end #Cheri
