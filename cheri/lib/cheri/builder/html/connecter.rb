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

HtmlConnecter = Cheri::Builder::TypeConnecter.new do

  # This covers the general case, and is all that is really
  # required here.
  type HtmlElement do
    connect HtmlElement, :add
    connect Cheri::Builder::Content
    # something non-html...
    connect Object, :add
  end
  
  # These provide more specific, and therefore more efficient (faster)
  # matching, as we won't have to search up the ancestor chain.
  type [Elem, EmptyElem, TextElem, EscElem, HtmlElem, BodyElem,
        HeadElem, TableElem, ProcElem] do
    connect Elem, :add
    connect EmptyElem, :add
    connect TextElem, :add
    connect EscElem, :add
    connect HtmlElem, :add
    connect BodyElem, :add
    connect HeadElem, :add
    connect TableElem, :add
    connect ProcElem, :add
  end

end #HtmlConnecter

end #Html
end #Cheri
