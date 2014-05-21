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

# WORKAROUND for JRUBY-3476 (no java_class for obj with singleton class)
# fixes reported Cheri "bug" #21960

x = java.lang.Object.new
# force singleton class
def x.foo; end
# redefine java_class if it doesn't work
class java::lang::Object
  def java_class
    self.class.java_class
  end
end unless x.java_class

# END WORKAROUND

module Cheri
module JRuby
#:stopdoc:
JU = JavaUtilities
JC = ::Java::JavaClass
RObj = 'org.jruby.RubyObject'
#:startdoc:
@unproxied = java.util.Collections.synchronized_map java.util.HashMap.new
class << self
  # call-seq:
  #   get_class(class_name [,proxy=true]) -> class/interface proxy or JavaClass
  # 
  # Returns the proxy for the specified class or interface if proxy=true (the default);
  # otherwise, returns the corresponding JavaClass. Getting a proxy class can be expensive
  # (the _first_ time it is referenced; subsequent calls retrieve it from cache). The
  # proxy=false option is therefore provided so we can get the JavaClass, a much less
  # expensive operation.  The JavaClass cannot be instantiated, but is used in Cheri
  # (Cheri::Swing and Cheri::AWT) for assignable_from? tests.
  def get_class(name,proxy=true)
    proxy ? JU.get_proxy_class(name) : @unproxied[name] ||= JC.for_name(name)
  end
  def runtime #:nodoc:
    @runtime ||= ::JRuby.runtime
  end
  def start_time #:nodoc:
    runtime.start_time  
  end
  # Returns +true+ if ObjectSpace is enabled.
  def object_space?
    runtime.object_space_enabled?  
  end
end #self

end #JRuby
end #Cheri