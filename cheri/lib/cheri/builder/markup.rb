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

class MarkupException < Cheri::CheriException; end

# Methods to support content (primarily intended for use with XML/HTML markup).
# Include after Attributes if both are used.
module Content
  def initialize(*r,&k)
    super
    @args.each do |arg|
      add arg
    end if @args  
  end

 # Adds +value+ to the content array (@cont) for this object if #add?(+value+)
 # returns +true+.
  def add(value)
    if add?(value)
      (@cont ||= []) << value
      @data = true unless Markup === value
    end
  end
  alias_method :<<, :add

  # Override to validate content before it is added. The default
  # implementation accepts any value.
  def add?(value)
    true
  end
  private :add?

  # Returns the content array (@cont) if present, otherwise +nil+.
  def content
    @cont
  end

 # Iterates over the content array (@cont) for this object. Equivalent to
 # calling #content#each.
  def each
    @cont.each do |content_elem|
      yield content_elem
    end if @cont && block_given?
  end
end #Content

# Methods to support attributes (primarily intended for use with XML/HTML markup).
# Include before Content if both are used.
module Attributes
  def initialize(*r,&k)
    super
    if (args = @args) && Hash === args.last
      args.pop.each_pair {|n,v| set(n,v) }
    end
  end

  # Sets an attribute. Called by #initialize to add/validate attributes
  # passed as arguments.
  def set(name,value)
    if @amap && (mname = @amap[name])
      name = mname
    end
    name = name.to_s.strip
    if set?(name,value)
      (@attrs ||= {})[name] = value
    end
  end
  alias_method :[]=, :set
  
  # Override to validate each attribute before it is set. The default
  # implementation accepts any name/value.
  def set?(name,value)
    true
  end
  private :set?
  
  # Returns the attibutes hash (@attrs), if any.
  def attrs
    @attrs  
  end
  
  # Returns the attribute value for +name+, or +nil+ if not set.
  def [](name)
    @attrs[name] if @attrs
  end
  
 # Iterates over the attributes hash (@attrs) for this object. Equivalent to
 # calling #attrs#each_pair.
  def each_attr
    @attrs.each_pair do |n,v|
      yield n,v
    end if @attrs && block_given?  
  end

end #Attributes

# Markup methods, used by Markup and MarkupLike
module MarkupMethods
  # :stopdoc:
  TC = '</'.freeze
  TE = '>'.freeze
  TEC = '></'.freeze
  TO = '<'.freeze
  TCE = ' />'.freeze
  LF = "\n".freeze
  TELF = ">\n".freeze
  S = ' '.freeze
  Q = '"'.freeze
  E = '='.freeze
  # :startdoc:

  # Append this markup to +str+ (or an empty string if +str+ is not supplied),
  # and return the result.  Redirects to #to_io if +str+ is not a String.  Both
  # methods use the +<<+ operator to append their output; this method (like the other
  # ..._s methods) is faster because Fixnum values can be appended directly, without
  # being converted to (or passed as) strings. This takes on particular significance
  # when output is being escaped, and values passed one character at a time.
  def to_s(str='')
    unless @fmt
      open_s(str)
      attr_s(str) if @attrs
      if @cont
        str << ?>
        cont_s(str)
        close_s(str)
      else
        empty_s(str)
      end
    else
      indent_s(str)
      open_s(str)
      attr_s(str) if @attrs
      if @cont
        unless @data
          str << TELF
          cont_s(str)
          indent_s(str)
        else
          str << ?>
          cont_s(str)
        end
        close_s(str)
        str << 10
      else
        empty_s(str)
        str << 10
      end
    end  
    str
  end

  # Calls #to_s.  Provided so that Markup/MarkupLike objects may be coerced to
  # Strings automatically. Implemented this way rather than through alias_method
  # to counter the possibility that overriders will forget to re-alias to_str.
  def to_str(str='')
    to_s(str)  
  end
  
  # Append value to the supplied output stream +ios+.  If  #esc is overridden
  # value will be escaped first.
  def to_io(ios)
    unless @fmt
      open_io(ios)
      attr_io(ios) if @attrs
      if @cont
        ios << TE
        cont_io(ios)
        close_io(ios)
      else
        empty_io(ios)
      end
    else
      indent_io(ios)
      open_io(ios)
      attr_io(ios) if @attrs
      if @cont
        unless @data
          ios << TELF
          cont_io(ios)
          indent_io(ios)
        else
          ios << TE
          cont_io(ios)
        end
        close_io(ios)
        ios << LF
      else
        empty_io(ios)
        ios << LF
      end
    end  
    ios
  end

  # Append open tag (<tagname) to +str+ using +<<+.
  def open_s(str)
    str << ?< << (@tag ||= (@ns && :no_ns != @ns ? "#{@ns}:#{@sym}" : @sym.to_s))
  end
  
  # Append open tag (<tagname) to +ios+ using +<<+.
  def open_io(ios)
    ios << TO << (@tag ||= (@ns && :no_ns != @ns ? "#{@ns}:#{@sym}" : @sym.to_s))
  end
  
  # Append close tag (</tagname>) to +str+ using +<<+.
  def close_s(str)
    str << TC << @tag << ?>
  end
  
  # Append close tag (</tagname>) to +ios+ using +<<+.  (Use slightly faster
  # #close_s for strings.)
  def close_io(ios)
    ios << TC << @tag << TE  
  end
  
  # Append empty close tag (...></tagname>) to +str+. Note that HTML/XML elements
  # with empty content models should close with <tt>' />'</tt> instead.
  def empty_s(str)
    str << TEC << @tag << ?>
  end
  
  # Append empty close tag (...></tagname>) to +ios+. Note that HTML/XML elements
  # with empty content models should close with <tt>' />'</tt> instead.
  def empty_io(ios)
    ios << TEC << @tag << TE
  end
  
  def indent_s(str)
    if (ind = margin + (indent * depth)) > 0
      str << Markup.sp(ind)    
    end
  end
  alias_method :indent_io,:indent_s
  
  # Writes attributes to a new string, or appends to an existing string
  # (using <<) if supplied.
  def attr_s(str='')
    @attrs.each_pair do |k,v|
      str << 32 << k << ?= << 34
      esc(v.to_s,str)
      str << 34
    end if @attrs
    str
  end

  # Writes attributes to the supplied IO stream (or Array, etc.) using <<.
  def attr_io(ios)
    @attrs.each_pair do |k,v|
      ios << S << k << E << Q << esc(v.to_s) << Q
    end if @attrs
    ios
  end

  # Appends concatenated and escaped content (@cont) to +str+, if supplied, using
  # the +<<+ operator.  Assumes String === +str+. Use #cont_io to append to IO or Array.
  def cont_s(str='')
    @cont.each do |v|
      case v
        when String : esc(v,str)
        when Markup 
          v.data! if @data
          v.depth = depth + 1
          v.to_s(str)
        when MarkupLike
          v.data! if @data
          v.to_s(str)
        else esc(v.to_s,str)
      end
    end if @cont
    str
  end

  # Appends concatenated and escaped content (@cont) to +ios+ using the +<<+ operator.
  # Use for appending to IO or Array. Use #cont_s to append more efficiently to strings.
  def cont_io(ios)
    @cont.each do |v|
      case v
        when String : ios << esc(v)
        when Markup
          v.data! if @data
          v.depth = depth + 1
          v.to_io(ios)
        when MarkupLike
          v.data! if @data
          v.to_io(ios)
        else ios << esc(v.to_s)
      end
    end if @cont
    ios
  end

  # Override to escape values (default implementation appends or returns
  # the input value unaltered).
  def esc(inp,out=nil)
    out ? out << inp : inp
  end

  def format?
    @fmt  
  end
  
  def format!
    @fmt = true  
  end
  
  def format=(fmt)
    @fmt = fmt
  end
  
  # Returns +true+ if content includes any non-Markup data. Not calling this cdata, as
  # that might not be accurate. Used by formatting code.
  def data?
    @data  
  end
  
  # Indicate that this element is embedded in data (mixed content) and should
  # therefore not be formatted.  This element should convey this to its
  # child elements, if any.
  def data!
    @data = true
    @fmt = false
  end
  
  def margin
    @mrg || @ctx[:margin] || 0
  end

  def margin=(n)
    @mrg = n  
  end
  
  def indent
    @idt || @ctx[:indent] || 0
  end
  
  def indent=(n)
    @idt = n  
  end
  
  def depth
    @dpt || 0  
  end
  
  def depth=(n)
    @dpt = n  
  end

  def tag
    @tag  
  end
  
  def tag=(tag)
    @tag = tag
  end
  
  # namespace
  def ns
    @ns
  end
  
  # set namespace
  def ns=(ns)
    @ns = ns
  end
end #MarkupMethods

module Markup
  include Attributes
  include Content
  include MarkupMethods
  # :stopdoc:
  @s = {}
  # :startdoc:

  # Return cached spaces string of length +n+
  def self.sp(n)
    @s[n] ||= (S * n).freeze
  end
end #Markup

# Includes the functionality of Markup, but isn't treated as Markup
# by other components. Used for Text/Esc elements, etc. so they can
# still embed Markup. (Useful for outputting viewable HTML, etc.)
module MarkupLike
  include Attributes
  include Content
  include MarkupMethods
end #MarkupLike

module EmptyMarkup
  include Markup
  # :stopdoc:
  TCE = ' />'.freeze
  # :startdoc:
  
  def add?(value)
    false
  end
  
  def empty_s(str='')
    str << TCE
  end

  def empty_io(ios)
    ios << TCE
  end

end #EmptyMarkup

module Comment
  include Markup
  # :stopdoc:
  CO = '<!-- '.freeze
  CC = ' -->'.freeze
  CCLF = " -->\n".freeze
  SPSP = '  '.freeze
  # :startdoc:

  def set?(n,v)
    raise MarkupException,"attribute not allowed for comment #{@sym}: #{n}=#{v}"  
  end
  private :set?
  
  def to_s(str='')
    return to_io(str) unless String === str
    unless @fmt
      str << CO
      cont_s(str) if @cont
      str << CC
    else
      indent_s(str)
      str << CO
      if @cont
        str << 10
        @data = nil
        cont_s(str)
        indent_s(str)
        str << CCLF
      else
        str << CCLF
      end
    end  
    str
  end
  
  def to_io(ios)
    unless @fmt
      ios << CO
      cont_io(ios) if @cont
      ios << CC
    else
      indent_io(ios)
      ios << CO
      if @cont
        ios << LF
        @data = nil
        cont_io(ios)
        indent_io(ios)
        ios << CCLF
      else
        ios << CCLF
      end
    end  
    ios
  end

  def cont_s(str='')
    @cont.each do |v|
      case v
        when String
          if @fmt
            indent_s(str)
            str << SPSP
            esc(v,str)
            str << 10
          else
            esc(v,str)
          end
        when Markup 
          v.data! if @data
          v.depth = depth + 1
          v.to_s(str)
        when MarkupLike
          v.data! if @data
          v.to_s(str)
        else esc(v.to_s,str)
      end
    end if @cont
    str
  end
  def cont_io(ios)
    @cont.each do |v|
      case v
        when String
          if @fmt
            indent_io(ios)
            ios << SPSP
            ios << esc(v)
            ios << LF
          else
            ios << esc(v)
          end
        when Markup
          v.data! if @data
          v.depth = depth + 1
          v.to_io(ios)
        when MarkupLike
          v.data! if @data
          v.to_io(ios)
        else ios << esc(v.to_s)
      end
    end if @cont
    ios
  end

end #Comment

module MarkupBuilder
  include Builder
  include Markup

  def object
    self  
  end

  def run
    if (k = @blk) && (val = @ctx.call(self,&k))
      add(val) if String === val
    end
    self
  end
end #MarkupBuilder

module MarkupLikeBuilder
  include Builder
  include MarkupLike

  def object
    self  
  end

  def run
    if (k = @blk) && (val = @ctx.call(self,&k))
      add(val) if String === val
    end
    self
  end
end #MarkupLikeBuilder

module EmptyMarkupBuilder
  include Builder
  include EmptyMarkup

  def object
    self  
  end

  def run
    if (k = @blk) && (val = @ctx.call(self,&k))
      # this should fail in add?
      add(val) if String === val
    end
    self
  end
end #EmptyMarkupBuilder

module CommentBuilder
  include Builder
  include Comment

  def object
    self  
  end

  def run
    if (k = @blk) && (val = @ctx.call(self,&k))
      add(val) if String === val
    end
    self
  end
end #CommentBuilder

end #Builder
end #Cheri
