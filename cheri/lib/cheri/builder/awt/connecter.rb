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
module AWT

AWTConnecter = Cheri::Builder::TypeConnecter.new(Cheri::Java::Builder::DefaultConnecter) do

  type java.awt.Component do
    connect java.awt.Font, :setFont
  end

  type java.awt.Container do
    connect java.awt.LayoutManager, :setLayout

    connect java.awt.Component do |par,obj,sym,props|
      if props
        cs = props[:constraints]
        ix = props[:index]
        n = props[:name]
        if cs && Fixnum === ix
          par.add(obj,cs,ix)
        elsif cs
          par.add(obj,cs)
        elsif Fixnum === ix
          par.add(obj,ix)
        elsif String === n
          par.add(n,obj)
        else
          par.add(obj)
        end
      else
        par.add(obj)
      end
    end

  end #java.awt.Container

end #AWTConnecter

end #AWT
end #Cheri
