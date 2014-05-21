#--
# Copyright (C) 2007,2008,2009 William N Dortch <bill.dortch@gmail.com>
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
module Java
JRuby = Cheri::JRuby #:nodoc:
ImageIcon = javax.swing.ImageIcon
CL = java.lang.ClassLoader
@icons = {}

#check for singleton/java_class bug in JRuby versions 1.1.4, 1.1.5 and 1.1.6 (see JRUBY-3476)
x = java.lang.Object.new
def x.foo; end
BUG_JRUBY_3476 = !x.java_class

class << self
  def get_class(*r)
    JRuby.get_class(*r)
  end
  # call-seq:
  #   Cheri::Java.get_icon(filename) -> icon
  #   
  # Returns an instance of LocatableIcon for file at #{Cheri.img_path}#{filename}.
  def get_icon(n)
    path = "#{Cheri.img_path}#{n}"
    @icons[path] ||= ImageIcon.new(CL.get_system_resource(path) || path)
  end
  # Returns the 16x16 Cheri icon.
  def cheri_icon
    @cheri_icon ||= get_icon('cheri_icon_16x16.png')
  end
end #self

end #Java
end #Cheri
