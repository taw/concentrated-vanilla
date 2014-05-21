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

# Marker 'interface' used by connecters.
module XmlElement
end #XmlElement

# Included by all Cheri::Xml builders
module XmlBuilder
  TCE = ' />'.freeze #:nodoc:

  def empty_s(str='')
    str << TCE
  end

  def empty_io(ios)
    ios << TCE
  end

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
end #XmlBuilder

class Elem
  include Cheri::Builder::MarkupBuilder
  include XmlBuilder
  include XmlElement
  
  def initialize(ctx,*r,&k)
    opt = @opt = ctx[:xml_opts] || {}
    @fmt = true if opt[:format]
    @amap = opt[:attr] if opt[:attr]
    super
  end

  def mod
    Cheri::Xml  
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
  include XmlBuilder
  include XmlElement

  def initialize(ctx,*r,&k)
    opt = @opt = ctx[:xml_opts] || {}
    @fmt = true if opt[:format]
    @amap = opt[:attr] if opt[:attr]
    super
  end
  
  def mod
    Cheri::Xml  
  end

  def add?(value)
    raise XmlException,"content not allowed for empty element #{@sym}: #{value}"  
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
  include XmlBuilder
  
  def initialize(ctx,*r,&k)
    @opt = ctx[:xml_opts] || {}
    super
  end

  def set?(n,v)
    raise XmlException,"attribute not allowed for text element #{@sym}: #{n}=#{v}"  
  end
  private :set?
  
  def mod
    Cheri::Xml  
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

# Like TextElem, but always escapes values, regardless of :esc setting
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
  include XmlBuilder
  include XmlElement
  # :stopdoc:
  CO = '<!-- '.freeze
  CC = ' -->'.freeze
  CCLF = " -->\n".freeze
  # :startdoc:
  def initialize(ctx,*r,&k)
    opt = @opt = ctx[:xml_opts] || {}
    @fmt = true if opt[:format]
    super
  end

  def set?(n,v)
    raise XmlException,"attribute not allowed for comment #{@sym}: #{n}=#{v}"  
  end
  private :set?
  
  def mod
    Cheri::Xml  
  end

  def margin
    @mrg || @opt[:margin] || @ctx[:margin] || 0
  end

  def indent
    @idt || @opt[:indent] || @ctx[:indent] || 0
  end

end #CommentElem

# TODO: special handling for these:

class XmlRoot
  # :stopdoc:
  XML = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>".freeze
  # :startdoc:
  include Cheri::Builder::MarkupBuilder
  include XmlBuilder

  def initialize(ctx,*r,&k)
    opt = @opt = ctx[:xml_opts] || {}
    @fmt = true if opt[:format]
    super
  end
  
  def mod
    Cheri::Xml  
  end

  def object
    self
  end
  
  def run
    @ctx.call(self,&@blk) if @blk
    self
  end

  # Appends content to +str+ (or new String if +str+ is omitted). Returns the result.
  def to_s(str='')
    return to_io(str) unless String === str
    str << ' ' * @opt[:margin] if @fmt && @opt[:margin]
    str << XML
    str << 10 if @fmt
    cont_s(str)
    str
  end

  # Appends content to +ios+. Returns the result.
  def to_io(ios)
    ios << ' ' * @opt[:margin] if @fmt && @opt[:margin]
    ios << XML
    ios << LF if @fmt
    cont_io(ios)
    ios
  end
  
  def format!
    @fmt = true  
  end
  
  def depth
    -1  
  end

end


class ProcElem < Elem
end

class Namespace
  alias_method :__methods__,:methods
  keep = /^(__|<|>|=)|^(class|inspect|to_s)$|(\?|!|=)$/
  instance_methods.each do |m|
    undef_method m unless m =~ keep  
  end

  def initialize(ctx,prefix,uri=nil)
    @ctx = ctx
    @pfx = prefix.to_sym
    @uri = uri if uri
  end
  
  def __prefix__
    @pfx  
  end
  
  def __uri__
    @uri  
  end
  
  def mod
    Cheri::Xml
  end
  private :mod

  def method_missing(sym,*r,&k)
    @ctx.nsend(mod,@pfx,sym,*r,&k)
  end
  private :method_missing

  def inspect
    "#<#{self.class}:instance>"  
  end

end #Namespace

end #Xml
end #Cheri