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

require 'thread'

# TODO: module comments
module Cheri
module VERSION #:nodoc:
  MAJOR = 0
  MINOR = 5
  TINY  = 0
  STRING = [MAJOR, MINOR, TINY].join('.').freeze
end
#:stopdoc:
PathExp = Regexp.new "cheri-#{VERSION::STRING}\\/lib$"
#:startdoc:
class CheriException < StandardError; end
class << self
  def type_error(object, *expected_type)
    TypeError.new("wrong argument type #{object.class} (expected #{expected_type.join(' or ')})")
  end  
  def argument_error(argc, expected_argc)
    ArgumentError.new("wrong number of arguments (#{argc} for #{expected_argc})")  
  end
  def load_path
    unless @load_path
      $LOAD_PATH.each do |path|
        if path =~ PathExp
          @load_path = "#{path}/"
          break
        end
      end    
    end
    @load_path ||= ''
  end
  def img_path
    @img_path ||= "#{load_path}cheri/image/"  
  end
end #self
end #Cheri
