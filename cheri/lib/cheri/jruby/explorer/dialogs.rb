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
module JRuby
module Explorer

class ConnectionDialog
  include Cheri::Swing
  def initialize(main)
    swing[:auto=>true]
    @main = main
    @main_frame = main.main_frame
    @dialog = dialog @main_frame, 'New Connection', true do |dlg|
      grid_table_layout dlg
      empty_border 4,4,4,4
      size 240,180
      default_close_operation :HIDE_ON_CLOSE
      grid_row do
        grid_table :i=>[0,8] do
          compound_border etched_border(:LOWERED), empty_border(7,7,7,7)
          defaults :i=>[4,1], :a=>:w
          grid_row {label 'Host:'; @con_host = text_field('localhost') {columns 10}}
          grid_row {label 'Port:'; @con_port = text_field {columns 10}}
          grid_row {label 'Display name:'; @con_name = text_field {columns 10}}
        end
      end
      grid_row  do
        grid_table :wy=>0.1, :a=>:s do
          grid_row :i=>4 do
            button('Connect') {on_click{do_connect}}
            button('Cancel') {on_click{@dialog.visible = false; reset_fields}}
          end
        end
      end
    end
    reset_fields
    @main.center(@main_frame,@dialog)
  end

  def reset_fields
    @con_host.text = 'localhost'
    @con_port.text = ''
    @con_name.text = ''
  end
  private :reset_fields
  
  def do_connect
    host = @con_host.text.strip
    port = @con_port.text.strip
    name = @con_name.text.strip
    name = nil if name.empty?
    if port.empty?
      JOptionPane.show_message_dialog(@main_frame,"Please enter a port number",
        'Connection Error', JOptionPane::ERROR_MESSAGE)
    elsif !(port = Integer(port) rescue nil)
      JOptionPane.show_message_dialog(@main_frame,"Invalid port: #{@con_port.text}",
        'Connection Error', JOptionPane::ERROR_MESSAGE)
    else
      @dialog.visible = false
      reset_fields
      @main.new_connection(port,name,host)
    end
  end
  private :do_connect
  
  def value
    @dialog  
  end
  
  def show
    @dialog.visible = true  
  end
  
  def hide
    @dialog.visible = false  
  end
  
end

class SearchDialog
  include Cheri::Swing
  def initialize(main)
    swing[:auto=>true]
    @main = main
    @main_frame = main.main_frame
    @dialog = dialog @main_frame, 'Search ObjectSpace', true do |dlg|
      grid_table_layout dlg, :a=>:nw, :wx=>0.1, :wy=>0.1, :f=>:h
      empty_border 4,4,4,4
      size 400,350
      default_close_operation :HIDE_ON_CLOSE
      grid_row{grid_table{
        defaults :a=>:w, :i=>[4,2]
        compound_border titled_border('Select instance') {etched_border :LOWERED}, empty_border(2,2,2,2)
        grid_row {label 'Instance:'; @instance_list = combo_box(instance_list,:f=>:h,:wx=>0.1) {editable false}}
      }}
      grid_row{grid_table{
        defaults :a=>:w,:i=>[4,2]
        compound_border titled_border('Find specific object') {etched_border :LOWERED}, empty_border(2,2,2,2)
        grid_row {
          label 'Object id:'
          @object_id = text_field(:wx=>0.1) {columns 16}
          button('Find') {on_click {find_by_id}}
        }
      }}
      grid_row{grid_table{
        defaults :a=>:w,:i=>[4,2]
        compound_border titled_border('Search for instances by type and optional variable/value') {etched_border :LOWERED},
          empty_border(2,2,2,2)
        grid_row {
          label 'Class or Module:', :w=>2
          @clazz = text_field(:wx=>0.1,:f=>:h) {columns 16}
          button('Find', :h=>3,:a=>:c) {on_click {find_by_type}}
        }
        grid_row {label 'Variable name:'; label '@',:i=>0,:a=>:e; @name1 = text_field(:wx=>0.1,:f=>:h) {columns 16}}
        grid_row {label 'Search string or /regexp/:',:w=>2; @value1 = text_field(:wx=>0.1,:f=>:h) {columns 16}}
        grid_row {@gc = check_box 'GC target instance before search', :a=>:c, :w=>4}
      }}
      grid_row {button('Cancel', :a=>:c, :wx=>0.1, :f=>:none) {on_click {@dialog.visible = false; reset_fields}}}
    end
    @main.center(@main_frame,@dialog)
  end

  def find_by_id
    id = nil_if_empty(@object_id.text)
    id = Integer(id) rescue nil if id
    if !id
      JOptionPane.show_message_dialog(@dialog,"Please enter a valid id",
        'Search Error', JOptionPane::ERROR_MESSAGE)
    else
      @dialog.visible = false
      @object_id.text = ''
      @main.new_find(@instances[@instance_list.selected_index],id)
    end
  end
  
  def find_by_type
    clazz = nil_if_empty(@clazz.text)
    name = nil_if_empty(@name1.text)
    value = @value1.text
    value = nil if value.empty?
    instance = @instances[@instance_list.selected_index]
    if !clazz
      JOptionPane.show_message_dialog(@dialog,"Please enter a Class or Module name",
        'Search Error', JOptionPane::ERROR_MESSAGE)
    elsif clazz !~ /^([A-Z])((\w|::[A-Z])*)$/
      JOptionPane.show_message_dialog(@dialog,"Invalid Class or Module name, please re-enter",
        'Search Error', JOptionPane::ERROR_MESSAGE)
    elsif name && name !~ /^([A-Za-z_])(\w*)$/
      JOptionPane.show_message_dialog(@dialog,"Invalid variable name, please re-enter",
        'Search Error', JOptionPane::ERROR_MESSAGE)
    elsif !instance.proxy.object_space?  && clazz != 'Class'
      JOptionPane.show_message_dialog(@dialog,"Only class 'Class' supported when ObjectSpace disabled",
        'Search Error', JOptionPane::ERROR_MESSAGE)
    else
      if value && value.strip.length != value.length
        rsp = JOptionPane.show_confirm_dialog(@main_frame,
          "Value contains leading/trailing whitespace -- continue?")
      else
        rsp = nil
      end
      unless rsp && rsp != JOptionPane::YES_OPTION
        @dialog.visible = false
        gc = @gc.selected
        reset_fields
        @main.new_search(instance,clazz,name,value,gc)
      end
    end
  end

  def nil_if_empty(val)
    if val
      val.strip!
      val = nil if val.empty?
    end
    val  
  end

  def reset_fields
    @clazz.text = ''
    @name1.text = ''
    @value1.text = ''
    @gc.selected = false
  end
  private :reset_fields
  
  def value
    @dialog  
  end
  
  def show(clazz = nil)
    @clazz.text = clazz if clazz
    update_instance_list
    @dialog.visible = true  
  end
  
  def hide
    @dialog.visible = false  
  end

  def instance_list
    @instances = @main.instance_list
    arr = Array.new(@instances.length) {|i|
       instance = @instances[i]
       pfx = instance.proxy.object_space? ? 'en' : 'dis'
       "#{instance.name}  [#{pfx}abled]"
    }
    arr.to_java
  end
  
  def update_instance_list
    new_list = instance_list
    @instance_list.remove_all_items
    new_list.each do |name|
      @instance_list.add_item name
    end
  end


end

class AboutDialog
  include Cheri::Swing
  include Cheri::Html

  # Undefining this so I can use it in Cheri::Html.  Could always
  # just use html.p instead.
  undef_method :p

  def initialize(main)
    swing[:auto]
    @main = main
    @main_frame = main.main_frame
    @dialog = dialog @main_frame, 'About Cheri::JRuby::Explorer', true do |d|
      size 600,450
      default_close_operation :HIDE_ON_CLOSE
      @view ||= scroll_pane do
        align :LEFT
        @html_view = editor_pane do
          editable false
          content_type 'text/html'
          html { head { style 'body { font-family: sans-serif; }' }
            body(:bgolor=>:white) { div(:align=>:center) {
            h3 font(:color=>:blue) {"Cheri::JRuby::Explorer version #{Cheri::VERSION::STRING}"}
            p 'Written by Bill Dortch ', esc('<cheri.project@gmail.com>'), br,
              'Copyright &copy; 2007-2009 William N Dortch'
            p
            table(:width=>'97%') {
              tr{td(:align=>:left) {
                p 'Cheri::JRuby::Explorer (CJX) demonstrates some of the features ',
                'of the Cheri builder framework, and may even prove useful ',
                'in its own right.  CJX is built using the Cheri::Swing and Cheri::Html ',
                'components of the framework.'
                p
                p 'This is a ',i('very'),' early Beta release, of both Cheri and CJX, so do ',
                'expect bugs, crashes, and the like. The Cheri framework itself is pretty ',
                'stable (though I refactor it weekly, it seems), but the CJX code is mostly ',
                'untested beyond the confines of my desktop.'
                p
                p 'For more information, and to report bugs or suggest features, please visit ',
                'the Cheri project pages on RubyForge, at ', a(b('http://cheri.rubyforge.org'), 
                :href=>'http://cheri.rubyforge.org/'), ' and ', a(b('http://rubyforge.org/projects/cheri'),
                :href=>'http://rubyforge.org/projects/cheri'), '.'
              }}
            }
          }}}
        end
      end
    end
     @main.center(@main_frame,@dialog)
  end
  
  def value
    @dialog  
  end
  
  def show
    @dialog.visible = true  
  end
  
  def hide
    @dialog.visible = false  
  end
  
end


end #Explorer
end #JRuby
end #Cheri