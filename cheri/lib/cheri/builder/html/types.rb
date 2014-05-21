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
Types = Hash[
  :tt => Elem,
  :i => Elem,
  :b => Elem,
  :big => Elem,
  :small => Elem,
  :em => Elem,
  :strong => Elem,
  :dfn => Elem,
  :code => Elem,
  :samp => Elem,
  :kbd => Elem,
  :var => Elem,
  :cite => Elem,
  :abbr => Elem,
  :acronym => Elem,
  :sub => Elem,
  :sup => Elem,
  :span => Elem,
  :bdo => Elem,
  :basefont => EmptyElem,
  :font => Elem,
  :br => EmptyElem,
  :body => BodyElem,
  :address => Elem,
  :div => Elem,
  :center => Elem,
  :a => Elem,
  :map => Elem,
  :area => EmptyElem,
  :link => EmptyElem,
  :img => EmptyElem,
  :object => Elem,
  :param => EmptyElem,
  :applet => Elem,
  :hr => EmptyElem,
  :p => Elem,
  :h1 => Elem,
  :h2 => Elem,
  :h3 => Elem,
  :h4 => Elem,
  :h5 => Elem,
  :h6 => Elem,
  :pre => Elem,
  :q => Elem,
  :blockquote => Elem,
  :ins => Elem,
  :del => Elem,
  :dl => Elem,
  :dt => Elem,
  :dd => Elem,
  :ol => Elem,
  :ul => Elem,
  :li => Elem,
  :dir => Elem,
  :menu => Elem,
  :form => Elem,
  :label => Elem,
  :input => EmptyElem,
  :select => Elem,
  :optgroup => Elem,
  :option => Elem,
  :textarea => Elem,
  :fieldset => Elem,
  :legend => Elem,
  :button => Elem,
  :table => TableElem,
  :caption => Elem,
  :thead => Elem,
  :tfoot => Elem,
  :tbody => Elem,
  :colgroup => Elem,
  :col => EmptyElem,
  :tr => Elem,
  :th => Elem,
  :td => Elem,
  :head => HeadElem,
  :title => Elem,
  :base => EmptyElem,
  :meta => EmptyElem,
  :style => Elem,
  :script => Elem,
  :noscript => Elem,
  :html => HtmlElem,
  :frameset => FramesetElem,
  :frame => EmptyElem,
  :text => TextElem,
  :t => TextElem,
  :text! => TextElem,
  :t1 => TextElem,
  :proc! => ProcElem,
  :esc => EscElem,
  :esc! => EscElem,
  :comment => CommentElem,
  :comment! => CommentElem,

# TODO: iframe, noframes

]

Aliases = Hash[
  :para => :p,
  :p! => :p,
]

end #Html
end #Cheri
