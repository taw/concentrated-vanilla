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

# Marker 'interface' used by connecter
module HtmlElement
end


# Included by all Cheri::Html builders
module HtmlBuilder
  def esc(inp,out=nil)
    if @opt[:esc] && (cs = Charsets.charset(inp))
      cs.xlat(inp,(out ||= ''))
      out
    elsif out
      out << inp
    else
      inp
    end
  end  
end #HtmlBuilder

class Elem
  include Cheri::Builder::MarkupBuilder
  include HtmlBuilder
  include HtmlElement

  def initialize(ctx,*r,&k)
    opt = @opt = ctx[:html_opts] || {}
    @fmt = true if opt[:format]
    @amap = opt[:attr] if opt[:attr]
    super
  end
  
  def mod
    Cheri::Html  
  end
  
  def margin
    @mrg || @opt[:margin] || @ctx[:margin] || 0
  end

  def indent
    @idt || @opt[:indent] || @ctx[:indent] || 0
  end
  
end

class EmptyElem
  include Cheri::Builder::EmptyMarkupBuilder
  include HtmlBuilder
  include HtmlElement

  def initialize(ctx,*r,&k)
    opt = @opt = ctx[:html_opts] || {}
    @fmt = true if opt[:format]
    @amap = opt[:attr] if opt[:attr]
    super
  end
  
  def mod
    Cheri::Html  
  end

  def add?(value)
    raise HtmlException,"content not allowed for empty element #{@sym}: #{value}"  
  end

  def margin
    @mrg || @opt[:margin] || @ctx[:margin] || 0
  end

  def indent
    @idt || @opt[:indent] || @ctx[:indent] || 0
  end
  
end


class TextElem
  include Cheri::Builder::MarkupLikeBuilder
  include HtmlBuilder
  
  def initialize(ctx,*r,&k)
    @opt = ctx[:html_opts] || {}
    super
  end
  
  def set?(n,v)
    raise HtmlException,"attribute not allowed for text element #{@sym}: #{n}=#{v}"  
  end
  private :set?
  
  def mod
    Cheri::Html  
  end

  # Appends content to +str+, or to an empty string if +str+ is omitted.
  # Returns the result.
  def to_s(str='')
    return to_io(str) unless String === str
    @cont.each do |c|
      if String === c
        esc(c,str)
      else
        esc(c.to_s,str)
      end
    end if @cont
    str
  end

  # Appends content to +ios+. Returns the result.
  def to_io(ios)
    @cont.each do |c|
      if String === c
        ios << esc(c)
      else
        ios << esc(c.to_s)
      end
    end if @cont
    ios
  end

end

class EscElem < TextElem

  def esc(inp,out=nil)
    if (cs = Charsets.charset(inp))
      cs.xlat(inp,(out ||= ''))
      out
    elsif out
      out << inp
    else
      inp
    end
  end  

end

class CommentElem
  include Cheri::Builder::CommentBuilder
  include HtmlBuilder
  include HtmlElement

  def initialize(ctx,*r,&k)
    opt = @opt = ctx[:html_opts] || {}
    @fmt = true if opt[:format]
    super
  end

  def set?(n,v)
    raise HtmlException,"attribute not allowed for comment #{@sym}: #{n}=#{v}"  
  end
  private :set?
  
  def mod
    Cheri::Html  
  end

  def margin
    @mrg || @opt[:margin] || @ctx[:margin] || 0
  end

  def indent
    @idt || @opt[:indent] || @ctx[:indent] || 0
  end

end #CommentElem

# TODO: special handling for these:

class HtmlElem < Elem
  LOOSE1 = "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\"\n"
  LOOSE2 = "        \"http://www.w3.org/TR/html4/loose.dtd\">\n"
  STRICT1 = "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\"\n"
  STRICT2 = "        \"http://www.w3.org/TR/html4/strict.dtd\">\n"
  Markup = Cheri::Builder::Markup

  def to_s(str='')
    return to_io(str) unless String === str
    if @opt[:doctype]
      strict = @opt[:strict]
      str << Markup.sp(margin) if @fmt
      str << (strict ? STRICT1 : LOOSE1)
      str << Markup.sp(margin) if @fmt
      str << (strict ? STRICT2 : LOOSE2)
    end
    super(str)
  end

  def to_io(ios)
    if @opt[:doctype]
      strict = @opt[:strict]
      ios << Markup.sp(margin) if @fmt
      ios << (strict ? STRICT1 : LOOSE1)
      ios << Markup.sp(margin) if @fmt
      ios << (strict ? STRICT2 : LOOSE2)
    end
    super(ios)
  end

end #HtmlElem

class BodyElem < Elem
end

class HeadElem < Elem
end

class TableElem < Elem
end

class FramesetElem < Elem
end

class ProcElem < Elem
end

end #Html
end #Cheri