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

class RootNodeViewer < HtmlNameValueListViewer
  include InstanceListener

  def initialize(*r,&k)
    super
    main.add_instance_listener(self)  
  end

  def title
    'Instances'
  end
  def icon
    CheriIcon
  end
  def table_rows
    main.instance_list.each do |inst|
      name_value_row(inst.name,inst.address)
    end  
  end
  def instance_added(instance)
    refresh
  end
  def instance_removed(instance)
    refresh  
  end
end #RootNodeViewer

class RubyInstanceViewer < HtmlNameValueListViewer
  def title
    @instance.name
  end

  def icon
    @instance.icon
  end

  def table_rows
    name_value_row('RUBY_PLATFORM',proxy.ruby_platform)
    name_value_row('RUBY_VERSION',proxy.ruby_version)
    name_value_row('RUBY_RELEASE_DATE',proxy.ruby_release_date)
    nil
  end
end #RubyInstanceViewer

class JRubyInstanceViewer < RubyInstanceViewer
  JVersion = 'java.version'
  JVendor = 'java.vendor'
  RtName = 'java.runtime.name'
  RtVersion = 'java.runtime.version'
  VmName = 'java.vm.name'
  VmVersion = 'java.vm.version'
  VmVendor = 'java.vm.vendor'

  def table_rows
    super
    env = proxy.env_java_brief
    name_value_row('JRUBY_VERSION',proxy.jruby_version)
    name_value_row('Java version',env[JVersion])
    name_value_row('Java vendor',env[JVendor])
    name_value_row('Runtime name',env[RtName])
    name_value_row('Runtime version',env[RtVersion])
    name_value_row('VM name',env[VmName])
    name_value_row('VM version',env[VmVersion])
    name_value_row('VM vendor',env[VmVendor])
    name_value_row('SecurityManager',proxy.security_manager)
    name_value_row('Available processors',proxy.available_processors)
    name_value_row('Total memory',"#{(proxy.total_memory/1000.0).round}K")
    name_value_row('Free memory',"#{(proxy.free_memory/1000.0).round}K")
    name_value_row('Maximum memory',"#{(proxy.max_memory/1000.0).round}K")
    name_value_row('ObjectSpace enabled',proxy.object_space?)
    name_value_row('JRuby start time',proxy.jruby_start_time)
    nil
  end
  
end #JRubyInstanceViewer

class LocalJRubyInstanceViewer < JRubyInstanceViewer
  def title
    'Local JRuby'  
  end
  def title_tab
    'Local'  
  end
end #LocalJRubyInstanceViewer

#class NameValueListViewer < HtmlNameValueListViewer
#
#end

class EnvViewer < HtmlNameValueListViewer
  def title
    "#{@instance.name}: ENV"
  end
  def title_tree
    'ENV'  
  end
  def icon
    VariablesIcon  
  end
  def leaf?
    true  
  end
  def table_rows
    env = proxy.env.sort
    env.each do |name,value|
      if Array === value
        value = value.sort rescue value
        name_value_row(name,value_list(value))  
      else    
        name_value_row(name,esc(value));
      end
    end
    nil
  end
end

class JavaEnvViewer < HtmlNameValueListViewer
  def title
    "#{@instance.name}: ENV_JAVA"
  end
  def title_tree
    'ENV_JAVA'  
  end
  def icon
    VariablesIcon  
  end
  def leaf?
    true  
  end
  def table_rows
    env = proxy.env_java.sort
    env.each do |name,value|
      if Array === value
        value = value.sort rescue value
        name_value_row(name,value_list(value))  
      else    
        name_value_row(name,esc(value));
      end
    end
    nil
  end
end

class GlobalVariablesViewer < HtmlNameValueListViewer
  def title
    "#{@instance.name}: global_variables"
  end
  def title_tree
    'global_vars'  
  end
  def title_tab
    "#{@instance.name}: global"
  end
  def icon
    VariablesIcon  
  end
  def leaf?
    true  
  end
  def table_rows
    vars = proxy.global_vars.sort
    vars.each do |name,value|
      if Array === value
        value = value.sort rescue value
        name_value_row(@esc = esc(name),value_list(value))
      else    
        name_value_row(@esc = esc(name),esc(value))
      end
    end
    nil
  end
end #GlobalVariablesViewer


class ConstantsViewer < HtmlNameValueListViewer
  include ParentViewerInterface
  include DRbHelper
    
  def title
    "#{@instance.name}: Module.constants"
  end
  def title_tree
    'constants'  
  end
  def title_tab
    "#{@instance.name}: const"
  end
  def icon
    ConstantIcon  
  end

  def table_rows
    consts = proxy.constants.sort
    consts.each do |name,type,value|
      # TODO: screen this in proxy?
      value = '' if value == name
      if Array === value
        value = value.sort rescue value
        name_type_value_row(name,type,value_list(value))  
      else    
        name_type_value_row(name,type,esc(value))
      end
    end
    nil
  end
  
  def load_children
    recs = drb_to_array(proxy.const_recs).sort
    children = []
    recs.each do |rec|
      ntv = case rec.clazz
        when 'Class' : NodeTypeValue.new(Class,rec.value,rec)
        when 'Module' : NodeTypeValue.new(Module,rec.value,rec)
        else NodeTypeValue.new(:constant,rec.clazz,rec)
      end
      children << ntv
    end
    @children = children
  end
  
  def children_loaded?
    @children  
  end

end #ConstantsViewer

class ConfigViewer < HtmlNameValueListViewer
  def title
    "#{@instance.name}: Config::CONFIG"
  end
  def title_tree
    'CONFIG'  
  end
  def title_tab
    "#{@instance.name}: CONFIG"
  end
  def icon
    VariablesIcon  
  end
  def leaf?
    true  
  end
  def table_rows
    cfg = proxy.config.sort
    cfg.each do |name,value|
      if Array === value
        value = value.sort rescue value
        name_value_row(name,value_list(value))  
      else    
        name_value_row(name,esc(value));
      end
    end
    nil
  end
end


# TODO: factor/generalize the header row code

class ObjectViewer < HtmlNameValueListViewer
  include ValueViewerInterface
  
  #:stopdoc:
  HdrInstVars = 'Instance variables'
  HdrInstVarName = 'Variable name'
  HdrName = 'Name'
  HdrType = 'Type'
  HdrId = 'Id'
  HdrValue = 'Value'
  Center = 'center'
  Left = 'left'
  Right = 'right'
  #:startdoc:

  def title
    "#{@instance.name}: #{@value.clazz}"
  end
  def title_tree
    "#{@value.clazz}" 
  end
  def title_tab
    "#{@instance.name}: #{@value.clazz}"
  end
  def icon
    ObjectIcon  
  end
  def leaf?
    true  
  end

  def table_rows
    value_header_row
    type_id_value_row(esc(@value.clazz),@value.id,esc(@value.value))
    instance_var_rows if value.vars
  end
  
  def instance_var_rows
    if (vars = value.vars)
      col_header_row HdrInstVarName
      vars.each do |name,type,value,id|
        if Array === value
          name_type_id_value_row(name,esc(type),id,value_list(value))
        else
          name_type_id_value_row(name,esc(type),id,esc(value))
        end
      end
      empty_row
    end
  end

  def header_row(hdr,cols=4)
    tr do
      th hdr, :bgcolor => NColor, :colspan => cols, :align => Left
    end  
  end

  def value_header_row
    tr do
      th HdrType, :bgcolor => NColor, :align => Left
      th HdrId, :bgcolor => NColor, :align => Right
      th HdrValue, :bgcolor => NColor, :align => Left
    end  
  end

  def col_header_row(name = HdrName)
    tr do
      th name, :bgcolor => NColor, :align => Left
      th HdrType, :bgcolor => NColor, :align => Left
      th HdrId, :bgcolor => NColor, :align => Right
      th HdrValue, :bgcolor => NColor, :align => Left
    end  
  end
end

class ConstantViewer < ObjectViewer
  def title
    "#{@instance.name}: #{@value.qname}"
  end
  def title_tree
    "#{@value.name}" 
  end
  def title_tab
    "#{@instance.name}: #{@value.name}"
  end
  def icon
    ConstantIcon  
  end
  
  def table_rows
    col_header_row 'Constant name'
    name_type_id_value_row(@value.name,esc(@value.clazz),@value.id,esc(@value.value))
    instance_var_rows if @value.vars
  end

end

class ModuleViewer < ConstantViewer
  include ParentViewerInterface
  include DRbHelper
  #:stopdoc:
  SuperClazz = 'Superclass'
  Ancestors = 'Ancestors'
  HdrAncName = 'Ancestor name'
  #:startdoc:
  
  def title
    "#{@instance.name}: #{@value.qname.empty? ? @value.value : @value.qname}"
  end
  def title_tree
    "#{@value.name}" 
  end
  def title_tab
    "#{@instance.name}: #{@value.name.empty? ? @value.value : @value.name}"
  end
  def icon
    ModuleIcon  
  end
  def leaf?
    false  
  end

  def html_heading
    val = @value
    div :align => :left do
    table :width => TblWidth, :cellspacing => 2, :cellpadding => 2, :border => 0 do
      tr do
        td esc(title), :class => :hdr, :align => :left, :colspan=> 2
      end
      tr do
        th val.clazz, :align => :left, :bgcolor => NColor, :width => 120
        td esc(val.qname.empty? ? val.value : val.qname), :align => :left, :bgcolor => VColor
      end
      tr do
        th HdrId, :align => :left, :bgcolor => NColor, :width => 120
        td val.id, :align => :left, :bgcolor => VColor
      end
      if (sc = val.superclazz)
        tr do
          th SuperClazz, :align => :left, :bgcolor => NColor, :width => 120
          td esc(sc), :align => :left, :bgcolor => VColor
        end      
      end
      empty_row
    end
    if (anc = val.ancestors) && (first = anc.first)
      anc.shift if first.id == val.id && first.value == val.qname
    end
    if anc && !anc.empty?
      table :width => TblWidth, :cellspacing => 2, :cellpadding => 2, :border => 0 do
        tr do
          th HdrAncName, :bgcolor => NColor, :align => Left
          th HdrType, :bgcolor => NColor, :align => Left, :width => '20%'
          th HdrId, :bgcolor => NColor, :align => Right, :width => '10%'
        end
        anc.each do |name,type,id|
          tr do
            td esc(name), :bgcolor => VColor
            td type, :width => '20%', :bgcolor => VColor
            td id, :width => '10%', :bgcolor => VColor, :align => Right, :class => :oid
          end      
        end
        empty_row
      end
    end
    end #div
  end
  
  def table_rows
    instance_var_rows if value.vars
    method_rows
  end

  def method_rows
    if (meths = @methods ||= proxy.module_methods(@value.qname,@value.id))
      if (ms = meths.pub) && !ms.empty?
        method_header_row 'Public class methods'
        ms.sort.each do |m| method_row(m); end
        empty_row
      end
      if (ms = meths.pub_inst) && !ms.empty?
        method_header_row 'Public instance methods'
        ms.sort.each do |m| method_row(m); end
        empty_row
      end
      if (ms = meths.pro) && !ms.empty?
        method_header_row 'Protected class methods'
        ms.sort.each do |m| method_row(m); end
        empty_row
      end
      if (ms = meths.pro_inst) && !ms.empty?
        method_header_row 'Protected instance methods'
        ms.sort.each do |m| method_row(m); end
        empty_row
      end
      if (ms = meths.pri) && !ms.empty?
        method_header_row 'Private class methods'
        ms.sort.each do |m| method_row(m); end
        empty_row
      end
      if (ms = meths.pri_inst) && !ms.empty?
        method_header_row 'Private instance methods'
        ms.sort.each do |m| method_row(m); end
        empty_row
      end
    end
  end
  
  def method_header_row(hdr,cols=4)
    tr do
      td b(hdr), :bgcolor => NColor, :colspan => cols
    end  
  end
  
  def method_row(meth,cols=4)
    tr td(esc(meth), :class => :method, :bgcolor => VColor, :colspan => cols)
  end

  def load_children
    recs = drb_to_array(proxy.const_recs(value.qname)).sort
    children = []
    recs.each do |rec|
      ntv = case rec.clazz
        when 'Class' : NodeTypeValue.new(Class,rec.value,rec)
        when 'Module' : NodeTypeValue.new(Module,rec.value,rec)
        else NodeTypeValue.new(:constant,rec.clazz,rec)
      end
      children << ntv
    end
    @children = children
  end
  
  def children_loaded?
    @children  
  end
  
  def refresh
    @methods = nil
    super  
  end

end

class ClassViewer < ModuleViewer
  def icon
    ClassIcon  
  end

end

class ResultListViewer < Viewer
  include ValueViewerInterface
  include NavViewerConstants
  #:stopdoc:
  Empty = '(empty)'
  #:startdoc:

  class ResultListItem
    def initialize(id,value)
      @i = id
      @v = value
    end
    def id
      @i
    end
    def v
      @v
    end
    alias_method :value,:v
    def ==(other)
      @v == other.v
    end    
    def eql?(other)
      @v.eql?(other.v)
    end
    def <=>(other)
      @v <=> other.v      
    end
    def to_s
      @v
    end
    alias_method :to_str, :to_s
    
  end #ResultListItem

#  def item_value(id)
#    @main.simple_value(@instance,id)
#  end
#
  def initialize(*r,&k)
    super
    create_object_list
  end
  
  def create_object_list
    res = @value.results
    proxy = @instance.proxy
    items = []
    res.length.times do |i|
      id = res[i]
      if (val = proxy.simple_value(id) rescue nil)
        val.strip!
        val = Empty if val.empty?
        items << ResultListItem.new(id,val)
      end
    end
    @obj_list = items.sort.to_java
  end

  def title
    "#{@instance.name}: Search Results"
  end
  def title_tree
    "Results" 
  end
  def title_tab
    "#{@instance.name}: Results"
  end
  def icon
    VariablesIcon  
  end

  # not expecting this to appear in trees, but if it does, it's a leaf
  def leaf?
    true
  end

  def view(&block)
    @view ||= scroll_pane do
      align :LEFT
      @top_view = y_panel do
        align :LEFT
        empty_border 4,4,4,4
        background :WHITE
        x_box do
          align :LEFT
          background :WHITE
          label title do
            align :LEFT
            set_font TFont
            foreground TColor
          end
          x_glue
        end
        @header = x_box do
          align :LEFT
          @cnames = y_panel do
            align :LEFT
            opaque false
            #background NColor
          end
          x_spacer 2
          @cvals = y_panel do
            align :LEFT
            opaque false
          end   
        end
        name_value_row('Class/Module',@value.args.clazz,CFont)
        if (vars = @value.args.vars) && !vars.empty?
          vname = vars[0].name.to_s
          vname = '  ' if vname.empty?
          vval = vars[0].value || '  '
          if Regexp === vval
            vval = vval.inspect
          elsif String === vval
            vval = '  ' if vval.empty?
          end
          name_value_row('Variable',vname)
          name_value_row('Value',vval)
        end
        last_row
        y_spacer 5
        x_box do
          align :LEFT
          label "=== found #{@value.length} objects ===" do
            align :LEFT
            foreground TColor
          end
        end
        y_spacer 3
        result_list
        y_spacer 3
        x_box do
          align :LEFT
          label '=== end of results ===' do
            align :LEFT
            foreground TColor
          end
        end
        # trying to get everything else pushed up
        y_glue
        y_panel do
          opaque false
        end
        y_glue
      end
    end
    super
  end
  
  def set_selection
    if (ix = @list.selected_index) >= 0
      @pending = ix
    end
  end
  def send_selection(new_tab=nil)
    if ix = @pending
      @pending = nil
      @main.show_result_object(self,@obj_list[ix].id,new_tab)
    end
  end
  def list_clicked(e)
    list = @list
    point = e.point
    if BUTTON1 == e.button &&
        (ix = list.location_to_index(point)) >= 0 &&
        list.get_cell_bounds(ix,ix).contains(point)
      send_selection((e.modifiers_ex & SHIFT) == SHIFT)
    end
  end

  def list_keyed(e)
    if @pending && e.action_key?
      send_selection((e.modifiers_ex & SHIFT) == SHIFT)
    end
  end
  
  def mouse_action(e)
    if e.popup_trigger?
      list = @list
      point = e.point
      if (ix = list.location_to_index(point)) >= 0 &&
          list.get_cell_bounds(ix,ix).contains(point)
        @menu_pending = ix
        selection_popup.show(e.component,e.x,e.y)
      end
    end
  end
  
  def menu_selection(new_tab)
    if ix = @menu_pending
      @menu_pending = nil
      @list.selected_index = ix
      send_selection(new_tab)
    end
  end
  
  def selection_popup
    @popup ||= popup_menu 'Open item in ... ' do
      menu_item 'Open in new tab' do
        on_click {menu_selection true}
      end
      menu_item 'Open in default tab' do
        on_click {menu_selection false}
      end
    end  
  end
  
  def result_list
    @list = list @obj_list do
      align :LEFT
      set_font ResFont
      foreground TColor
      selection_mode :SINGLE_SELECTION
      on_value_changed do |e|
        unless e.value_is_adjusting
          set_selection
        end
      end
      on_mouse_clicked   {|e| list_clicked e}
      on_mouse_pressed   {|e| mouse_action e}
      on_mouse_released  {|e| mouse_action e}
      on_key_pressed     {|e| list_keyed e}
      on_key_released    {|e| list_keyed e}
    end
  end
  
  def name_value_row(name,value,vfont=VFont)
    cheri_yield @cnames do
      x_panel do
        align :LEFT
        background NColor
        maximum_size 200,28
        on_mouse_entered do |e|
          e.source.background = HColor
        end
        on_mouse_exited do |e|
          e.source.background = NColor
        end
        x_spacer 2
        label name do
          align :LEFT,:CENTER
          set_font NFont
        end
        #x_glue
      end
      y_spacer 2
    end
    cheri_yield @cvals do
      x_panel do
        align :LEFT
        background VColor
        x_spacer 2
        label value do
          align :LEFT,:CENTER
          set_font vfont
        end
        x_glue
      end
      y_spacer 2
    end
  end

  def last_row
    cheri_yield @cnames do y_glue; end
    cheri_yield @cvals  do y_glue; end
  end
  
  def close_view
    @main.close_results_view(self)
  end
end

class GBLObjectViewer
  include ViewerInterface
  include ValueViewerInterface
  include GBLViewer
  
  include Cheri::Swing

  def title
    "#{@instance.name}: #{@value.clazz} value"
  end
  
  def title_tree
    "#{@value.clazz}" 
  end

  def title_tab
    title
  end

  def icon
    ObjectIcon  
  end

  def leaf?
    true  
  end

  def view
    @view ||= scroll_pane {
      grid_table{ #Body
        background :WHITE
        opaque true
        defaults :a=>:nw, :wx=>0.1, :wy=>0.0, :f=>:h
        grid_row{ #Title
          cell_label title, TFont, White, TColor
        } #Title
        grid_row{ #Value
          grid_table{
            defaults :a=>:nw, :wx=>0.0, :wy=>0.0, :f=>:h, :i=>CellInset
            opaque false
            header_row ['Id','Type','Value'], NFont, NColor, Black, :px=>16

            grid_row(:f=>:both, :wy=>0.1, :px=>12){
              cell_label @value.id.to_s, VFont, VColor, Black
              cell_label @value.clazz, VFont, VColor, Black
              value_label @value.value, VFont, VColor, Black, :px=>0, :wx=>0.1
            }
          }
        } #Value

        # FIXME: forcing stuff upwards; there *must* be a better way...
        grid_row{empty_cell(:a=>:se, :wy=>0.1, :f=>:v)}
      } #Body
    } # scroll_pane
  end
  
end #GBLObjectViewer

class GBLModuleViewer
  include ViewerInterface
  include ValueViewerInterface
  include ParentViewerInterface
  include GBLViewer

  include Cheri::Swing
  include DRbHelper
  
  def title
    "#{@instance.name}: #{@value.qname.empty? ? @value.value : @value.qname}"
  end

  def title_tree
    "#{@value.name}" 
  end

  def title_tab
    "#{@instance.name}: #{@value.name.empty? ? @value.value : @value.name}"
  end

  def icon
    ModuleIcon  
  end

  def leaf?
    false  
  end

  def load_children
    recs = drb_to_array(proxy.const_recs(value.qname)).sort
    children = []
    recs.each do |rec|
      ntv = case rec.clazz
        when 'Class' : NodeTypeValue.new(Class,rec.value,rec)
        when 'Module' : NodeTypeValue.new(Module,rec.value,rec)
        else NodeTypeValue.new(:constant,rec.clazz,rec)
        
      end
      children << ntv
    end
    @children = children
  end
  
  def children_loaded?
    !!@children  
  end
  
  def send_selection(id,new_tab=nil)
    @main.show_linked_object(self,id,new_tab)
  end

  def mouse_clicked(e,id)
    send_selection(id,(e.modifiers_ex & SHIFT) == SHIFT)
  end

  def mouse_action(e,id)
    if e.popup_trigger?
      @menu_pending = id
      selection_popup.show(e.component,e.x,e.y)
    end
  end
  
  def menu_selection(new_tab)
    if id = @menu_pending
      @menu_pending = nil
      send_selection(id,new_tab)
    end
  end
  
  def selection_popup
    @popup ||= popup_menu 'Open item in ... ' do
      menu_item 'Open in new tab' do
        on_click {menu_selection true}
      end
      menu_item 'Open in default tab' do
        on_click {menu_selection false}
      end
    end  
  end

  def title_section
    grid_row{
      cell_label title, TFont, White, TColor
    }
  end

  def header_section
    val = @value
    grid_row{ #Header
      grid_table {
        defaults :a=>:nw, :f=>:both, :wx=>0.0, :wy=>0.0, :i=>CellInset
        opaque false
        grid_row{
          cell_label 'Module', NFont, NColor, Black
          cell_label(val.qname.empty? ? val.value : val.qname, VFont, VColor, Black, :wx=>0.1)
        }
        grid_row{
          cell_label 'Id', NFont, NColor, Black
          cell_label(val.id.to_s, VFont, VColor, Black, :wx=>0.1)
        }
      }
    } #Header
  end

  def ancestors_section
    val = @value
    if (anc = val.ancestors) && (first = anc.first)
      anc.shift if first.id == val.id && first.value == val.qname
    end
    return unless anc && !anc.empty?

    grid_row{ #Ancestors
      grid_table {
        defaults :a=>:nw, :f=>:h, :wx=>0.0
        opaque false
        header_row ['Id', 'Ancestor name', 'Type'], NFont, NColor, Black, :px=>16, :i=>[16,0,1,1]
        anc.each {|name,type,id|
          grid_row(:i=>[0,0,1,1], :f=>:both, :a=>:nw, :wy=>0.1, :px=>12){
            click_label id.to_s, id, VFont, VColor, Color::CYAN, Black
            click_label name, id, VFont, VColor, Color::CYAN, Black
            cell_label type, VFont, VColor, Black
          }
        }
      }
    } #Ancestors
  end
  
  def variables_section
    val = @value
    return unless (vars = val.vars) && !vars.empty?
    
    grid_row{ #Variables
      grid_table {
        defaults :a=>:nw, :f=>:h, :wx=>0.0
        opaque false
        header_row ['Id', 'Variable name', 'Type', 'Value'], NFont, NColor, Black, :px=>16, :i=>[16,0,1,1]
        vars.each {|name,type,value,id|
          value = value + '...' if value.length >= 100
          grid_row(:i=>[0,0,1,1], :f=>:both, :a=>:nw, :wy=>0.1, :px=>12){
            click_label id.to_s, id, CFont, VColor, Color::CYAN, Black
            click_label name, id, IFont, VColor, Color::CYAN, Black
            cell_label type, CFont, VColor, Black
            value_label value, VFont, VColor, TColor,  :px=>0, :wx=>0.0
          }
        }
      }
    } #Variables
  end
  
  def methods_section
    return unless (methods = @methods ||= proxy.module_methods(@value.qname,@value.id))
    [
      [methods.pub,'Public class methods'],
      [methods.pub_inst,'Public instance methods'],
      [methods.pro,'Protected class methods'],
      [methods.pro_inst,'Protected instance methods'],
      [methods.pri,'Private class methods'],
      [methods.pri_inst,'Private instance methods']
    ].each do |meths, title|
      if meths && !meths.empty?
        grid_row{cell_label title, NFont, NColor, Black, :i=>HeaderInset}
        meths.sort.each do |name|
          grid_row{cell_label name, VFont, VColor, Black, :i=>LineInset}
        end
      end    
    end  
  end

  def view
    @view ||= scroll_pane {
      val = @value
      grid_table{ #Body
        background :WHITE
        opaque true
        defaults :a=>:nw, :wx=>0.1, :wy=>0.0, :f=>:h

        title_section

        header_section
        
        ancestors_section
        
        variables_section
        
        methods_section
        
        # FIXME: forcing stuff upwards; there *must* be a better way...
        grid_row{empty_cell(:a=>:se, :wy=>0.1, :f=>:v)}
      } #Body
    } # scroll_pane
  end

end #GBLModuleViewer

class GBLClassViewer < GBLModuleViewer

  def icon
    ClassIcon  
  end

  def header_section
    val = @value
    superclazz = val.superclazz
    grid_row{ #Header
      grid_table {
        defaults :a=>:nw, :f=>:both, :wx=>0.0, :wy=>0.0, :i=>CellInset
        opaque false
        grid_row{
          cell_label 'Class', NFont, NColor, Black
          cell_label(val.qname.empty? ? val.value : val.qname, VFont, VColor, Black, :wx=>0.1)
        }
        grid_row{
          cell_label 'Id', NFont, NColor, Black
          cell_label(val.id.to_s, VFont, VColor, Black, :wx=>0.1)
        }
        grid_row{
          cell_label 'Superclass', NFont, NColor, Black
          cell_label(superclazz, VFont, VColor, Black, :wx=>0.1)
        } if superclazz
      }
    } #Header
  end

end #GBLClassViewer


register_viewer(:root_node,nil,RootNodeViewer)
register_viewer(:ruby_instance,nil,RubyInstanceViewer)
register_viewer(:jruby_instance,nil,JRubyInstanceViewer)
register_viewer(:env,nil,EnvViewer)
register_viewer(:env_java,nil,JavaEnvViewer)
register_viewer(:global_vars,nil,GlobalVariablesViewer)
register_viewer(:global_const,nil,ConstantsViewer)
register_viewer(:config,nil,ConfigViewer)
register_viewer(:constant,nil,ConstantViewer)
register_viewer(:object,nil,GBLObjectViewer)
register_viewer(Module,nil,GBLModuleViewer)
register_viewer(Class,nil,GBLClassViewer)
register_viewer(:results,nil,ResultListViewer)


end #Explorer
end #JRuby
end #Cheri
