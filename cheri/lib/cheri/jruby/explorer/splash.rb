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
module JRuby
module Explorer
class SplashScreen
  include Cheri::Swing
  Font = ::Java::JavaAwt::Font
  def initialize
    swing[:auto => true]
  end
  def splash(&block)
    img_path = Cheri.img_path
    @panel ||= y_panel do
      align :LEFT
      background :WHITE; bevel_border :LOWERED
      y_spacer 56
      x_box do
        x_glue
        x_spacer 20
        y_box do
          label image_icon("#{img_path}cheri_logo_medium.png")
          y_spacer 100
        end
        y_box do
          y_spacer 100
          label image_icon("#{img_path}jruby_logo.png")
        end
        x_spacer 50
        x_glue
      end
      x_box do
        label 'E x p l o r e r' do
          font 'Dialog', Font::BOLD|Font::ITALIC, 100; align :CENTER; foreground :BLUE
        end
        x_spacer 50
      end
      y_glue
      x_box do
        label '(C) 2007 Bill Dortch.  JRuby logo (C) 2006 Codehaus Foundation.' do
          foreground :GRAY; font 'Dialog',:BOLD,11
        end
      end
      x_box do
        label 'Some icons (C) Freeiconsweb http://www.freeiconsweb.com' do
          foreground :GRAY; font 'Dialog',:BOLD,11
        end
      end
    end
    cheri_yield(panel,&block) if block
    @panel
  end
end #SplashScreen

end #Explorer
end #JRuby
end #Cheri
