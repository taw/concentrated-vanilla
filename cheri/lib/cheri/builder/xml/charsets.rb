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
module Charsets
SPECIAL = /[\000-\010\013\014\016-\037\046\074\076\200-\377]/
HIBYTES = /[\200-\377]/
class << self
  def special?(str)
    str =~ SPECIAL  
  end
  # Returns a Charset if +str+ requires translation, else +nil+
  def charset(str)
    return nil unless str =~ SPECIAL
    if str =~ HIBYTES
      Utf8.detect?(str) ? Utf8 : Win1252
    else
      Iso8859    
    end
  end
end #self
module Charset
  def xlat(i,o)
    m = @map
    i.each_byte do |b| o << m[b]; end
  end
  def map
    @map  
  end
end

module Win1252
  extend Charset
  @map = Array.new(256)
  map = @map
  0.upto(31) do |i| map[i] = 32; end
  map[9] = ?\t
  map[10] = ?\n
  map[13] = ?\r
  32.upto(127) do |i| map[i] = i; end
  map[38] = '&amp;'
  map[60] = '&lt;'
  map[62] = '&gt;'
  # windows-1252 mappings
  map[128] = '&#x20AC;'
  map[129] = '?' #undefined
  map[130] = '&#x201A;'
  map[131] = '&#x192;'
  map[132] = '&#x201E;'
  map[133] = '&#x2026;'
  map[134] = '&#x2020;'
  map[135] = '&#x2021;'
  map[136] = '&#x2C6;'
  map[137] = '&#x2030;'
  map[138] = '&#x160;'
  map[139] = '&#x2039;'
  map[140] = '&#x152;'
  map[141] = '?' #undefined
  map[142] = '&#x17D;'
  map[143] = '?' #undefined
  map[144] = '?' #undefined
  map[145] = '&#x2018;'
  map[146] = '&#x2019;'
  map[147] = '&#x201C;'
  map[148] = '&#x201D;'
  map[149] = '&#x2022;'
  map[150] = '&#x2013;'
  map[151] = '&#x2014;'
  map[152] = '&#x2DC;'
  map[153] = '&#x2122;'
  map[154] = '&#x161;'
  map[155] = '&#x203A;'
  map[156] = '&#x153;'
  map[157] = '?' #undefined
  map[158] = '&#x17E;'
  map[159] = '&#x178;'
  # 160-255 same for windows-1252 & ISO 8859-1 (Latin-1)
  160.upto(255) do |i| map[i] = "&##{i};"; end
end

module Iso8859
  extend Charset
  # using same map for windows-1252 & ISO 8859-1, since the
  # only detectable difference is use of 0x80-0x9f
  @map = Win1252.map
end 

module Utf8
  extend Charset

  # TODO: not quite correct for EO, F0, F4 ?
  def self.detect?(str)
    d = @detect
    ct = 0
    begin
      str.each_byte do |b|
        if b < 128
          return false if ct > 0        
        elsif b < 192
          return false if (ct -= 1) < 0
        else
          return false unless ct == 0
          ct += d[b]
        end
      end #each_byte
      ct == 0
    rescue
      false    
    end
  end

  @map = Array.new(256)
  map = @map
  0.upto(31) do |i| map[i] = 32; end
  map[9] = ?\t
  map[10] = ?\n
  map[13] = ?\r
  32.upto(255) do |i| map[i] = i; end
  map[38] = '&amp;'
  map[60] = '&lt;'
  map[62] = '&gt;'

  @detect = Array.new(256)
  det = @detect
  0x80.upto(0xBF) do |i| det[i] = -1; end
  0xC2.upto(0xDF) do |i| det[i] = 1; end
  0xE0.upto(0xEF) do |i| det[i] = 2; end
  0xF0.upto(0xF4) do |i| det[i] = 3; end
end
end #Charsets
end #Xml
end #Cheri
