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

# Frame provides default implementations of the methods required by objects that
# will be pushed onto the Cheri::Builder::Context stack.  Note that concrete
# builders will need to override some of these methods, such as #mod, #parent? 
# and #child?.
#
# Frame is provided as a convenience; its use is not required.
#
# If used, Frame should normally be included before other Cheri::Builder convenience
# modules (such as Content or Attributes). Classes/modules that include it should
# be sure to call super from their initialize methods, if any.
module Frame
  # Stores the context and block (if any) in @ctx and @blk.
  def initialize(ctx,*args,&blk) #:doc:
    @ctx = ctx
    @blk = blk if blk
    super(*args)
  end
  
  # Returns @ctx, the Context instance to which this frame belongs.
  def ctx
    @ctx  
  end
  alias_method :context, :ctx

  # Returns @blk, the block passed to this frame, if any.
  def block
    @blk
  end

  # Perform whatever actions are required to build +object+. Normally overridden to 
  # create +object+ and call its block, if any.  Should return the built object.
  # 
  # The default implementation simply calls +block+, if present. (Note that the block
  # is actually called indirectly, via Cheri::Builder::Context#call, which manages
  # the stack and connections. You normally do _not_ want to call the block directly.)
  def run
    @ctx.call(self,&@blk) if @blk
  end

  # The object for this frame (builder). Normally the object being built, once it has
  # been created. May be the same as the builder object (see Cheri::Html::Elem, for example).
  def object
    @obj
  end
  
  # The builder module (such as Cheri::Swing) associated with this frame (builder object).
  # Normally must be overridden. Default: Cheri::Builder::CheriModule
  def mod
    CheriModule  
  end

  # Override to return +true+ if +object+ can be a parent of other objects. Default: +false+
  def parent?
    false
  end

  # Override to return +true+ if +object+ can be a child of another object. Default: +false+
  def child?
    false
  end
  
  # Override to return +true+ if +object+ wants the opportunity to connect to any object
  # created in the hierarchy below it. Normally used by non-structural components (Swing's
  # ButtonGroup, for example). Adds build overhead, so use sparingly.
  def any?
    false
  end
     
  # Overrides the default Object#inspect to prevent mind-boggling circular displays in IRB.
  def inspect
   to_s  
  end

end #Frame

module Parent
  def parent?
    true
  end
end

module Child
  def child?
    true  
  end
end

# Builder extends the functionality of Frame, extracting the symbol (+sym+) and arguments
# (+args+) from the arguments passed by a factory.  Like Frame, it is a convenience that
# may be included in (or otherwise used to extend) builder classes/objects.
module Builder
  include Frame
  # Calls super to store context and block, then stores sym and args in @sym and @args.
  def initialize(ctx,sym,*args,&blk) #:doc:
    super(ctx,&blk)
    @sym = sym
    @args = args
  end

  # Returns the symbol passed by the factory that created this builder. The symbol
  # normally originates in the method_missing method of the client object.
  def sym
    @sym
  end

  # Returns the arguments (excluding ctx and sym) passed by the factory that created
  # this builder.
  def args
    @args  
  end

  def run
    @ctx.call(self,&@blk) if @blk
    @obj
  end
  
  # Overrides Frame#parent? to return +true+.
  def parent?
    true  
  end
  
  # Overrides Frame#child? to return +true+.
  def child?
    true
  end
end

module DynamicModule
  def initialize(mod,*r,&k)
    @mod = mod
    super(*r,&k)  
  end
  
  def mod
    @mod  
  end
end
# An 'abstract' builder class. Includes the methods defined in Frame and Builder.
# Provided as a convenience.
class AbstractBuilder
  include Builder
end # AbstractBuilder


# A convenience 'base' builder class.  Breaks the #run method into several steps.
class BaseBuilder < AbstractBuilder

  def run
    pre
    create unless @no_create
    post
    call unless @no_call
    @obj
  end

  # Returns ! @not_parent
  def parent?
   ! @not_parent
  end

  # Returns ! @not_child 
  def child?
   ! @not_child  
  end

private
  # called before object created
  def pre #:doc:
  end

  # override to create object
  def create #:doc:
  end

  # called after object is created
  def post #:doc:
  end

  # called to call block unless there is no block or @no_call is set
  def call #:doc:
    @ctx.call(self,&@blk) if @blk
  end
end #BaseBuilder

end #Builder
end #Cheri
