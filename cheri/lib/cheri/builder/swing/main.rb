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

module Swing
VERSION = Cheri::VERSION

CJava = Cheri::Java #:nodoc:
CBuilder = Cheri::Builder #:nodoc:
JBuilder = Cheri::Java::Builder #:nodoc:
AWT = Cheri::AWT #:nodoc:
AWTFrame = Cheri::AWT::AWTFrame #:nodoc:
AWTProxy = Cheri::AWT::AWTProxy #:nodoc:
JComp = javax.swing.JComponent #:nodoc:
RPC = javax.swing.RootPaneContainer #:nodoc:
# types checked by cherify/cheri_yield logic
# TODO: more
SwingTypes = [
  javax.swing.Action,
  javax.swing.JComponent,
  javax.swing.RootPaneContainer,
  javax.swing.border.Border
]
SwingPkg = 'javax.swing.'

class << self
  def append_features(clazz)
    CBuilder.module_included(Cheri::AWT,clazz)
    CBuilder.module_included(JBuilder,clazz)
    CBuilder.module_included(self,clazz)
    super
  end
  private :append_features
  
  def factory
    SwingFactory  
  end
  
  def connecter
    SwingConnecter  
  end
  
  def consumer
    SwingConsumer
  end

  def resolver
    SwingResolver  
  end
    
  # a bit expensive, but only used by cherify/cheri_yield
  def swing?(obj)
    obj.respond_to?(:java_class) &&
      (obj.java_class.name.rindex(SwingPkg,0) ||
       !(obj.class.ancestors & SwingTypes).empty?)
  end
end #self

  # call-seq:
  #   awt([*args] [, &block]) -> AWTProxy if no block given, else result of block
  #
  #--
  # Duplicating this here rather than including Cheri::AWT. (See note re: performance)
  #++
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

  # call-seq:
  #   swing([*args] [, &block]) -> SwingProxy if no block given, else result of block
  #   
  def swing(*r,&k)
    if ctx = __cheri_ctx
      if k
        if ctx.empty? && (c = ctx.client).kind_of?(RPC) || c.kind_of?(JComp)
          ctx.fsend(CheriYieldFactory,:cheri_yield,c,&k)
        else
          SwingFrame.new(ctx,*r,&k).run
        end
      else
        ctx[:swing_proxy] ||= SwingProxy.new(ctx,*r)
      end
    end
  end
  private :swing

AnyTypes = {
  javax.swing.ButtonGroup => true
}

class BaseBuilder < Cheri::Java::Builder::BaseBuilder
  JF = CJava.get_class('javax.swing.JFrame')

  def mod
    Cheri::Swing
  end

  def any?
    @any  
  end

private
  def post
    @obj.icon_image ||= CJava.cheri_icon.image if @obj.kind_of?(JF)
    if AnyTypes[@clazz]
      @any = true
      @not_parent = true
      @not_child = true
    end
  end
end #BaseBuilder

class ClassBuilder < BaseBuilder
  def initialize(ctx,sym,clazz,*args,&block)
    super(ctx,sym,*args,&block)
    @clazz = clazz
    @resolve = true
  end
private
  def create
    @obj = @clazz.new(*@args)
  end
end #ClassBuilder

class ProcBuilder < BaseBuilder
  def initialize(ctx,sym,proc,*args,&block)
    super(ctx,sym,*args,&block)
    @proc = proc
  end
private
  def create
    @obj = @proc.call(*@args)
    @clazz = @obj.class
    @resolve = true
  end
end #ProcBuilder

class PropAwareClassBuilder < ClassBuilder
private
  def create
    if Hash === @props    
      @args << @props
      @props = nil
    end
    @obj = @clazz.new(*@args)
  end
end #PropAwareProcBuilder

class CherifyBuilder < BaseBuilder
  def initialize(ctx,sym,obj,*args,&block)
    super(ctx,sym,*args,&block)
    @obj = obj
    @clazz = obj.class
    @no_create = true
    @resolve = true
  end
end #CherifyBuilder

class CheriYieldBuilder < BaseBuilder
  def initialize(ctx,sym,obj,*args,&block)
    super(ctx,sym,*args,&block)
    @obj = obj
    @clazz = obj.class
    @no_create = true
    @not_child = true
    @resolve = true
  end
end #CheriYieldBuilder

# TODO: comments
module CherifyFactory
  S = ::Cheri::Swing #:nodoc:
  def self.builder(ctx,sym,*args,&block)
    return nil unless sym == :cherify && !args.empty? && S.swing?(args[0])
    raise Cheri.argument_error(args.length,1..2) unless args.length == 1 || args.length == 2
    CherifyBuilder.new(ctx,sym,*args,&block)
  end
end #CherifyFactory

# TODO: comments
module CheriYieldFactory # < Cheri::AbstractFactory
  S = ::Cheri::Swing #:nodoc:
  def self.builder(ctx,sym,*args,&block)
    return nil unless sym == :cheri_yield && !args.empty? && S.swing?(args[0])
    raise Cheri.argument_error(args.length,1) unless args.length == 1
    CheriYieldBuilder.new(ctx,sym,*args,&block)
  end
end #CheriYieldFactory

# TODO: comments
module StandardFactory
  def self.builder(ctx,sym,*args,&block)
    clazz = Types.get_class(sym)
    clazz ? ClassBuilder.new(ctx,sym,clazz,*args,&block) : nil
  end
end #StandardFactory

module GridTableFactory
  SwingLayout = org.cheri.swing.layout
  @names = [:grid_table_layout,:grid_table,:grid_row,:empty_cell]
  def self.builder(ctx,sym,*args,&block)
    case sym
    when :grid_table_layout
      PropAwareClassBuilder.new(ctx,sym,SwingLayout::GridTableLayout,*args,&block)
    when :grid_table
      ClassBuilder.new(ctx,sym,SwingLayout::GridTable,*args,&block)
    when :grid_row
      ClassBuilder.new(ctx,sym,SwingLayout::GridRow,*args,&block)
    when :empty_cell
      ClassBuilder.new(ctx,sym,SwingLayout::EmptyCell,*args,&block)
    else
      nil
    end
  end
  def self.names
    @names
  end
end

module BoxComponentFactory
CJava = Cheri::Java
X_AXIS = 0
Y_AXIS = 1
LINE_AXIS = 2
PAGE_AXIS = 3
RPC = javax.swing.RootPaneContainer
@box = nil
@box_layout = nil
@panel = nil
@dimension = nil
@procs = {}
class << self
  def builder(ctx,sym,*args,&block)
    if proc = @procs[sym]
      ProcBuilder.new(ctx,sym,proc,*args,&block)
    end
  end
  def box
    @box ||= CJava.get_class('javax.swing.Box')
  end
  def box_layout
    @box_layout ||= CJava.get_class('javax.swing.BoxLayout')
  end
  def panel
    @panel ||= CJava.get_class('javax.swing.JPanel')
  end
  def dimension
    @dimension ||= CJava.get_class('java.awt.Dimension')
  end
  def names
    @names ||= @procs.keys
  end  
end #self

@procs[:box_layout] =
  Proc.new do |obj,axis|
    iaxis = case axis
      when :X_AXIS : X_AXIS
      when :Y_AXIS : Y_AXIS
      when :LINE_AXIS : LINE_AXIS
      when :PAGE_AXIS : PAGE_AXIS
      else axis    
    end
    box_layout.new(obj.kind_of?(RPC) ? obj.content_pane : obj,iaxis) 
  end
@procs[:x_box] = @procs[:h_box] = @procs[:horizontal_box] = Proc.new { box.new(X_AXIS) }
@procs[:y_box] = @procs[:v_box] = @procs[:vertical_box] = Proc.new { box.new(Y_AXIS) }
@procs[:line_box] = Proc.new { box.new(LINE_AXIS) }
@procs[:page_box] = Proc.new { box.new(PAGE_AXIS) }
@procs[:x_panel] = @procs[:h_panel] = @procs[:horizontal_panel] =
  Proc.new do |*args|
    p = panel.new(*args)
    p.setLayout(box_layout.new(p,X_AXIS))
    p
  end
@procs[:y_panel] = @procs[:v_panel] = @procs[:vertical_panel] =
  Proc.new do |*args|
    p = panel.new(*args)
    p.setLayout(box_layout.new(p,Y_AXIS))
    p
  end
@procs[:line_panel] = 
  Proc.new do |*args|
    p = panel.new(*args)
    p.setLayout(box_layout.new(p,LINE_AXIS))
    p
  end
@procs[:page_panel] = 
  Proc.new do |*args|
    p = panel.new(*args)
    p.setLayout(box_layout.new(p,PAGE_AXIS))
    p
  end
@procs[:glue] = Proc.new { box.createGlue }
@procs[:x_glue] = @procs[:h_glue] = @procs[:horizontal_glue] = Proc.new { box.createHorizontalGlue }
@procs[:y_glue] = @procs[:v_glue] = @procs[:vertical_glue] =  Proc.new { box.createVerticalGlue }
@procs[:x_strut] = @procs[:h_strut] = @procs[:horizontal_strut] =
  Proc.new do |*args|
    box.createHorizontalStrut(*args)
  end
@procs[:y_strut] = @procs[:v_strut] = @procs[:vertical_strut] = 
  Proc.new do |*args|
    box.createVerticalStrut(*args)
  end
@procs[:rigid_area] = @procs[:spacer] = 
  Proc.new do |*args|
    box.createRigidArea(dimension.new(*args))
  end
@procs[:x_spacer] = @procs[:h_spacer] = @procs[:horizontal_spacer] =
  Proc.new do |*args|
    box.createRigidArea(dimension.new(args[0],0))
  end
@procs[:y_spacer] = @procs[:v_spacer] = @procs[:vertical_spacer] =
  Proc.new do |*args|
    box.createRigidArea(dimension.new(0,args[0]))
  end
@procs[:filler] =
  Proc.new do |*args| 
    box::Filler.new(dimension.new(args[0],args[1]),
                    dimension.new(args[2],args[3]),
                    dimension.new(args[4],args[5]))
  end
end #BoxComponentFactory


# TODO: more factories

module DialogComponentFactory
CJava = Cheri::Java
  
end #DialogComponentFactory


SwingFactory = Cheri::Builder::SuperFactory.new do |f|
  f << StandardFactory
  f << GridTableFactory
  f << BoxComponentFactory
  f << Cheri::AWT::StandardFactory
  f << CheriYieldFactory
  f << CherifyFactory
  f << Cheri::Java::Builder::CheriYieldFactory
  f << Cheri::Java::Builder::CherifyFactory
  f << Cheri::Builder::CheriYieldFactory
  f << Cheri::Builder::CherifyFactory
end

class SwingProxy < Cheri::AWT::AWTProxy

  impl(Types.names)
  impl(BoxComponentFactory.names)
  impl(GridTableFactory.names)

  def initialize(ctx,*r)
    super
    if Hash === r.last
      @ctx.auto!(mod) if r.last[:auto]
    end  
  end

  def mod
    Cheri::Swing  
  end
  private :mod

  def [](opts)
    raise Cheri.type_error(opts,Hash,Symbol) unless Hash === opts || Symbol === opts
    if opts == :auto || (Hash === opts && opts[:auto])
      @ctx.ictx.auto!(mod)
      @ctx.auto!(mod)
#      if (c = @ctx.client).kind_of?(RPC) || c.kind_of?(JComp)
#        @ctx.push(b = CheriYieldBuilder.new(@ctx,:cheri_yield,c))
#        b.run
#      else
#        @ctx.push(SwingFrame.new(@ctx))
#      end
    end
    nil
  end
end #SwingProxy

class SwingFrame
  include Cheri::Builder::Frame
  def initialize(ctx,*r,&k)
    super
    @obj = ctx[:swing_proxy] ||= SwingProxy.new(ctx,*r)  
  end

  def mod
    Cheri::Swing
  end
end #SwingFrame

SwingResolver = Cheri::Java::Builder::ConstantResolver.new do |r|
  r << Cheri::AWT::Constants
  r << Constants
end

module AlignMethodConsumer
  BOTTOM = 1.0
  CENTER = 0.5
  LEFT = 0.0
  RIGHT = 1.0
  TOP = 0.0
  JComp = javax.swing.JComponent

  def self.consume(ctx,bld,sym,*args,&k)
    return false,nil unless sym == :align && (obj = bld.object).kind_of?(JComp)
    argc = args.length
    raise Cheri.new_argument_error(argc,1..2) unless argc == 1 || argc == 2
    x_val = nil
    y_val = nil
    0.upto(argc-1) do |i|
      arg = args[i]
      if arg.kind_of?(Numeric)
        unless argc == 2
          raise ArgumentError,"align can't evaluate numeric value with only one argument -- specify both x and y"
        end
        i == 0 ? x_val = arg : y_val = arg
      else
        raise ArgumentError,"invalid argument for align: #{arg}" unless arg.instance_of?(Symbol)
        case arg
          when :TOP : y_val = TOP
          when :BOTTOM : y_val = BOTTOM
          when :LEFT : x_val = LEFT
          when :RIGHT : x_val = RIGHT
          when :CENTER :
            if argc ==2
              i == 0 ? x_val = CENTER : y_val = CENTER
            else
              x_val = y_val = CENTER
            end
          else raise ArgumentError,"invalid argument for align: #{arg}"
        end
      end
    end
    obj.alignment_x = x_val if x_val
    obj.alignment_y = y_val if y_val
    return true,nil
  end
end #AlignMethodConsumer

SwingConsumer = Cheri::Builder::SuperConsumer.new do |c|
  c << AlignMethodConsumer
  c << Cheri::AWT::SizeMethodConsumer
  c << Cheri::Java::Builder::EventMethodConsumer
  c << Cheri::Java::Builder::GenericConsumer
  c << Cheri::Builder::DefaultConsumer
end

end #Swing
end #Cheri
