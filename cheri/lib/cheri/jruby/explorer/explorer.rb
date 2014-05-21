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
class ExplorerException < StandardError; end
CJava = Cheri::Java
CheriIcon = CJava.cheri_icon
ClassIcon = CJava.get_icon('cls_tree.png')
ModuleIcon = CJava.get_icon('mod_tree.png')
RubyIcon = CJava.get_icon('ruby_16x16.png')
JRubyIcon = CJava.get_icon('jruby_14x16.png')
VariablesIcon = CJava.get_icon('vars_tree.png')
ConstantIcon = CJava.get_icon('con_tree.png')
ObjectIcon = CJava.get_icon('obj_tree.png')
CloseTabIcon = CJava.get_icon('close_12x12.png')
CloseTabDimIcon = CJava.get_icon('close_dim2_12x12.png')
CloseActiveIcon = CJava.get_icon('close_24x24.png')
System = ::Java::JavaLang::System
JOptionPane = ::Java::JavaxSwing::JOptionPane

# UI look-and-feel init adapted from JConsole
UIManager = ::Java::JavaxSwing::UIManager
unless System.get_property "swing.defaultlaf"
  system_laf = UIManager.getSystemLookAndFeelClassName
  if system_laf == "com.sun.java.swing.plaf.gtk.GTKLookAndFeel" ||
      system_laf == "com.sun.java.swing.plaf.windows.WindowsLookAndFeel"
    UIManager.setLookAndFeel(system_laf) rescue nil
  end
end
laf_name = UIManager.getLookAndFeel.getClass.getName
LAF_IS_GTK = laf_name == "com.sun.java.swing.plaf.gtk.GTKLookAndFeel"
LAF_IS_WIN = laf_name == "com.sun.java.swing.plaf.windows.WindowsLookAndFeel"

# main entry point
def self.run
  Main.new.run
end

class Main
  include Cheri::Swing
  
  import java.lang.Math
  import java.lang.System
  import java.lang.Thread
  import java.util.WeakHashMap
  import javax.swing.JComponent
  import javax.swing.JOptionPane
  
  FindIcon = CJava.get_icon('Find24.gif')
  FindAgainIcon = CJava.get_icon('FindAgain24.gif')
  SearchIcon = CJava.get_icon('Search24.gif')
  RefreshIcon = CJava.get_icon('Refresh24.gif')
  CloseIcon = CJava.get_icon('Delete24.gif')
  # TODO: I *hate* these next two -- find replacements!
  NextIcon = CJava.get_icon('Forward24.gif')
  PrevIcon = CJava.get_icon('Back24.gif')
  ClassIcon = CJava.get_icon('class_16x16.png')
  ModuleIcon = CJava.get_icon('mod_tree.png')
  Viewers = Cheri::JRuby::Explorer
  RubyExplorer = Cheri::Explorer::RubyExplorer
  jver = ENV_JAVA['java.version']
  Java5 = String === jver && jver >= '1.5'
  Java6 = String === jver && jver >= '1.6'
  MAIN_TITLE = "Cheri::JRuby::Explorer  v#{Cheri::VERSION::STRING}    (JRuby v#{JRUBY_VERSION})"

  # Maps viewer types into tab slots. Uncategorized viewers 
  # will be opened in tabs slots based on their primary type.
  TypeTabMap = {
    :root_node    => :root_node,
    :env          => :misc,
    :env_java     => :misc,
    :global_vars  => :misc,
    :global_const => :misc,
    :config       => :misc,
    :object       => :object,
    :constant     => :constant,
    Class         => :constant,
    Module        => :constant,
    :results      => :results,
  }
  # Shareable NodeType instances (for non-NodeTypeValue types). 
  NodeTypes = {}
  TypeTabMap.keys.each do |type|
    NodeTypes[type] = NodeType.new(type)
  end
  
  def initialize
    swing[:auto => true]
    @instances = {}
    @instance_listeners = []  
    @main_tabs = {}
    @result_tabs = {}
    @main_tab_history = []
    @main_tabs[:global] = {}
    @result_tabs[:global] = {}
    @local_instance = JRubyInstance.new(RubyExplorer.new,'Local','local')
    add_instance(@local_instance)
  end

  def run
    splash_screen = SplashScreen.new.splash
    main_frame do |frame|
      cherify(splash_screen)
    end
    bounds = @main_frame.graphics_configuration.bounds
    @main_frame.set_location(Math.max(0,(bounds.width - 800)/2), Math.max(0,(bounds.height - 760)/2))
    @main_frame.show
    @main_frame.to_front
    sleep 1.5
    @main_tree.selection_row = 0
    @main_frame.content_pane.remove(splash_screen)
    @main_menu.visible = true
    @main_tool_bar.visible = true
    @main_panel.visible = true
    @footer_panel.visible = true
    @result_tab_pane.visible = false
  end

  def release_resources
    #puts 'release_resources called'
  end

  def main_frame(&block)
    
    @main_frame ||= frame MAIN_TITLE do |frame|
      size 800,600
      box_layout frame, :Y_AXIS
      #content_pane do box_layout frame, :Y_AXIS; end
      on_window_closing do
        release_resources
        @main_frame.dispose
      end
      main_menu_bar
      main_tool_bar
      main_panel do 
        main_splitter do
          left_pane do
            main_tree_pane do
              main_tree
            end
          end
          right_pane do
            right_splitter do
              main_tab_pane
              result_tab_pane
            end
          end
        end
      end
      footer_panel
    end
    cheri_yield(@main_frame,&block) if block
    @main_frame
  end

  def main_menu_bar(&block)
    @main_menu ||= menu_bar do |bar|
      visible false
      file_menu
      connect_menu
      view_menu
      search_menu
      help_menu
    end
    cheri_yield(@main_menu,&block) if block
    @main_menu
  end

  def file_menu(&block)
    @file_menu ||= menu 'File' do |menu|
      mnemonic :VK_F
      menu_item 'Exit' do |item|
        mnemonic :VK_X
        on_click do |e|
          release_resources
          @main_frame.dispose
        end
      end
    end
    cheri_yield(@file_menu,&block) if block
    @file_menu
  end

  def connect_menu(&block)
    @connect_menu ||= menu 'Connect' do |mn|
      mnemonic :VK_C
      menu_item 'New connection ...' do
        on_click do
          connection_dialog.show        
        end      
      end
    end
    cheri_yield(@connect_menu,&block) if block
    @connect_menu
  end

  def view_menu(&block)
    @view_menu ||= menu 'View' do |mn|
      mnemonic :VK_V
      @results_select = check_box_menu_item 'Search Results pane' do
        selected true
        on_click do |e|
          if (@result_tab_pane.visible = e.source.selected = !@result_tab_pane.visible)
            adjust_right_splitter
          end
        end      
      end
      separator
      button_group do
        radio_button_menu_item 'Wrap Tabs', true do
          mnemonic :VK_W
          on_click do |e|
            cheri_yield @main_tab_pane do tab_layout_policy :WRAP_TAB_LAYOUT; end
          end
        end
        radio_button_menu_item 'Scroll Tabs' do
          mnemonic :VK_S
          on_click do |e|
            cheri_yield @main_tab_pane do tab_layout_policy :SCROLL_TAB_LAYOUT; end
          end
        end
      end #button_group
      separator
      menu_item 'Refresh active view' do
        on_click do
          refresh_active_view        
        end      
      end
      menu_item 'Close active view' do
        on_click do
          close_active_view        
        end      
      end
      menu_item 'Close current search results' do
        on_click do
          close_active_search_view        
        end      
      end
    end
    cheri_yield(@view_menu,&block) if block
    @view_menu
  end

  def search_menu(&block)
    @search_menu ||= menu 'Search' do |mn|
      mnemonic :VK_S
      menu_item 'Search ObjectSpace ...' do
        mnemonic :VK_S
        on_click do
          show_search_dialog        
        end
      end
      menu_item 'Repeat last search' do
        mnemonic :VK_R
        on_click do
          repeat_search
        end
      end
    end
    cheri_yield(@search_menu,&block) if block
    @search_menu
  end

  def help_menu(&block)
    @help_menu ||= menu 'Help' do |menu|
      mnemonic :VK_H
      menu_item 'About ...' do |item|
        mnemonic :VK_X
        on_click do |e|
          show_about_dialog
        end
      end
    end
    cheri_yield(@help_menu,&block) if block
    @help_menu
  end

  def main_tool_bar(&block)
    @main_tool_bar = tool_bar 'CJRX Tools' do |tbar|
      box_layout tbar, :X_AXIS
      align :LEFT
      floatable false
      visible false
      matte_border 0,0,2,0,tbar.background.darker
      button RefreshIcon do
        tool_tip_text 'Refresh active view'
        on_click do
          refresh_active_view
        end
      end
      button FindIcon do
        tool_tip_text 'Search ObjectSpace'
        on_click do
          show_search_dialog       
        end      
      end
      button FindAgainIcon do
        tool_tip_text 'Repeat last search'
        on_click do
          repeat_search
        end
      end
      button SearchIcon do
        tool_tip_text "We don't know what this does yet"
      end
      x_glue
      button PrevIcon do
        tool_tip_text 'Previous tab view'
        on_click {prev_view}
      end
      button NextIcon do
        tool_tip_text 'Next tab view'
        on_click {next_view}
      end
      button CloseActiveIcon do
        tool_tip_text 'Close active view'
        on_click do
          close_active_view        
        end      
      end
      #x_glue
      x_spacer 10
    end
    cheri_yield(@main_tool_bar,&block) if block
    @main_tool_bar
  end

  def main_splitter(&block)
    @main_splitter ||= split_pane :HORIZONTAL_SPLIT do |spane|
      empty_border 4,3,0,0
      align :LEFT
      divider_location 200
    end
    cheri_yield(@main_splitter,&block) if block
    @main_splitter
  end
  
  def right_splitter(&block)
    @right_splitter ||= split_pane :VERTICAL_SPLIT do |spane|
      align :LEFT
      divider_location 450
    end
    cheri_yield(@right_splitter,&block) if block
    @right_splitter
  end

  def adjust_right_splitter
    if @right_splitter.divider_location > (max = @right_splitter.maximum_divider_location - 120)
      @right_splitter.divider_location = max
    end
  end
  
  def left_pane(&block)
    @left_pane ||= y_panel
    cheri_yield(@left_pane,&block) if block
    @left_pane
  end

  def right_pane(&block)
    @right_pane ||= y_panel
    cheri_yield(@right_pane,&block) if block
    @right_pane
  end

  def main_tree_pane(&block)
    @main_tree_pane ||= scroll_pane
    cheri_yield(@main_tree_pane,&block) if block
    @main_tree_pane
  end

  def main_tab_pane(&block)
    unless @main_tab_pane
      @main_tab_pane = tabbed_pane
      @main_tab_pane.extend TabbedPaneMethods    
    end
    cheri_yield(@main_tab_pane,&block) if block
    @main_tab_pane
  end

  def result_tab_pane(&block)
    unless @result_tab_pane
      @result_tab_pane = tabbed_pane do
        align :LEFT
      end
      @result_tab_pane.extend TabbedPaneMethods
    end
    cheri_yield(@result_tab_pane,&block) if block
    @result_tab_pane
  end

  def main_panel(&block)
    @main_panel ||= y_panel do # superflous?
      align :LEFT
      visible false
    end
    cheri_yield(@main_panel,&block) if block
    @main_panel
  end

  def footer_panel(&block)
    @footer_panel ||= x_panel do
      align :LEFT
      visible false
      label '' do align :CENTER; end
    end
    cheri_yield(@footer_panel,&block) if block
    @footer_panel
  end

  def main_tree_model(&block)
    @main_tree_model ||= default_tree_model root_tree_node
  end

  def main_tree(&block)
    @main_tree ||= tree main_tree_model do |t|
      root_tree_node do
        new_instance_node @local_instance, :tree => t      
      end
      cell_renderer ExplorerTreeCellRenderer.new
      selection_model do
        selection_mode :SINGLE_TREE_SELECTION
      end
      on_value_changed do |e|
        update_selected_node_view
      end
      on_tree_will_expand do |e|
        node = e.path.last_path_component
        prepare_for_node_expansion(node) if ParentViewerInterface === node.user_object
      end
#      on_mouse_clicked do |e|
#      end
    end
    cheri_yield(@main_tree,&block) if block
    @main_tree
  end
  
  def root_tree_node(&block)
    @root_tree_node ||= ExplorerTreeNode.new viewer(:root_node).new(NodeTypes[:root_node],self,nil,@instances)
    cheri_yield(@root_tree_node,&block) if block
    @root_tree_node
  end

  def new_tree_node(viewer,*r,&block)
    tree_node = ExplorerTreeNode.new(viewer)
    cherify(tree_node,*r,&block)
    tree_node
  end

  def new_instance_node(instance,*r,&block)
    type = instance.type
    node = new_tree_node(viewer(type).new(nil,self,instance),*r,&block)
    instance.tree_node = node
    # TODO: add mechanism to define instance sub-nodes so custom nodes may be added
    cheri_yield(node) do
      new_tree_node(viewer(:env).new(NodeTypes[:env],self,instance))
      new_tree_node(viewer(:env_java).new(NodeTypes[:env_java],self,instance)) if :jruby_instance == type
      new_tree_node(viewer(:config).new(NodeTypes[:config],self,instance))
      new_tree_node(viewer(:global_vars).new(NodeTypes[:global_vars],self,instance))
      new_tree_node(viewer(:global_const).new(NodeTypes[:global_const],self,instance))
    end
    node
  end
  
  def add_instance_node(instance)
    root_tree_node do
      new_instance_node instance    
    end
  end

  def update_selected_node_view
    node = main_tree.last_selected_path_component
    return unless node && node.respond_to?(:user_object) && (viewer = node.user_object)
    view = viewer.view
    tabs = main_tab_pane
    unless tabs.include?(view)
      set_view_viewer(view,viewer)
      if instance = viewer.instance
        tab_group = instance.__id__
      else
        tab_group = :global
      end
      ntype = viewer.type.type
      tab_type = TypeTabMap[ntype] || ntype
      current_viewer = @main_tabs[tab_group][tab_type]
      if current_viewer && (index = tabs.index(current_viewer.view))
        replace_view_tab(tabs,view,viewer,index)
      else
        add_view_tab(tabs,view,viewer)
      end
      @main_tabs[tab_group][tab_type] = viewer
    end
    tabs.set_selected_component(view)
  end

  def add_view_tab(tabs,view,viewer)
    cheri_yield tabs do
      cherify(view, :tab => viewer.tab, :title => viewer.title_tab, :icon => viewer.icon_tab)
    end
    if tabs == @main_tab_pane
      index = tabs.index(view)
      @main_tab_history[index] = TabHistory.new(viewer)
    end
  end 
  
  def replace_view_tab(tabs,view,viewer,index)
    tabs[index] = view
    if Java6 && (tab = viewer.tab)
      tabs[index,:tab] = tab
    else
      tabs[index,:title] = viewer.title_tab
      tabs[index,:icon] = viewer.icon_tab
    end
    if tabs == @main_tab_pane
      if hist = @main_tab_history[index]
        hist << viewer
      else
        @main_tab_history[index] = TabHistory.new(viewer)
      end
    end
  end

  def prepare_for_node_expansion(node)
    unless node.child_count > 0
      vwr = node.user_object
      vwr.load_children unless vwr.children_loaded?
      instance = vwr.instance
      children = vwr.children
      tree = @main_tree
      cheri_yield node do
        children.each do |ntv|
          if NodeType === ntv && (clazz = viewer(ntv.type,ntv.subtype))
            if NodeTypeValue === ntv
              # TODO: passing value twice, because the ValueViewerInterface
              # currently requires it as separate arg. rethink interface.
              nvwr = clazz.new(ntv,self,instance,ntv.value)
            else
              nvwr = clazz.new(ntv,self,instance)
            end
            new_tree_node nvwr, :tree => tree
          else       
            warn "can't create node/viewer for #{ntv}"
          end
        end
      end
    end
  end

  def set_view_viewer(view,viewer)
    # TODO: JRuby TODO: proxy not rematched with object when object returned from Java
    #view.extend ComponentViewMethods unless ComponentViewMethods === view
    #view.viewer = viewer
    raise Cheri.type_error(view,JComponent) unless JComponent === view
    view.put_client_property(:viewer,viewer)
  end
  
  def view_viewer(view)
    view.get_client_property(:viewer)  
  end

  def next_view
    tabs = main_tab_pane
    if (oldvwr = tabs.active_viewer) &&
        (ix = tabs.index(oldvwr.view)) &&
        (hist = @main_tab_history[ix]) &&
        (newvwr = hist.next!)
      replace_view(tabs,ix,newvwr)
    end
  end
  
  def prev_view
    tabs = main_tab_pane
    if (oldvwr = tabs.active_viewer) &&
        (ix = tabs.index(oldvwr.view)) &&
        (hist = @main_tab_history[ix]) &&
        (newvwr = hist.prev!)
      replace_view(tabs,ix,newvwr)
    end
  end
  
  def replace_view(tabs,index,viewer)
    tabs[index] = viewer.view
    if Java6 && (tab = viewer.tab)
      tabs[index,:tab] = tab
    else
      tabs[index,:title] = viewer.title_tab
      tabs[index,:icon] = viewer.icon_tab
    end
  end

  def refresh_active_view
    if (viewer = main_tab_pane.active_viewer)
      viewer.refresh if viewer.respond_to?(:refresh)    
    end
  end
  
  def close_active_view
    if (viewer = main_tab_pane.active_viewer)
      close_view(viewer)    
    end
  end
  
  def close_active_search_view
    if (viewer = result_tab_pane.active_viewer)
      close_results_view(viewer)    
    end
  end
  
  def close_view(viewer)
    view = viewer.view
    index = (tabs = main_tab_pane).index(view)
    tabs.remove(view)
    @main_tab_history.delete_at(index)
    if instance = viewer.instance
      tab_group = instance.__id__
    else
      tab_group = :global    
    end
    ntype = viewer.type.type
    tab_type = TypeTabMap[ntype] || ntype
    @main_tabs[tab_group].delete(tab_type) if @main_tabs[tab_group][tab_type] == viewer
    @main_tabs[tab_group].delete(viewer.__id__)
  end

  def close_results_view(viewer)
    view = viewer.view
    result_tab_pane.remove(view)
    if instance = viewer.instance
      tab_group = instance.__id__
    else
      tab_group = :global    
    end
    ntype = viewer.type.type
    tab_type = TypeTabMap[ntype] || ntype
    @result_tabs[tab_group].delete(tab_type) if @result_tabs[tab_group][tab_type] == viewer
    @result_tabs[tab_group].delete(viewer.__id__)
  end

  def close_views_for_instance(inst)
    # TODO: search views
    views = main_tab_pane.select {|view| view_viewer(view).instance == inst}
    views.each do |view|
      close_view(view_viewer(view))    
    end
    views = result_tab_pane.select {|view| view_viewer(view).instance == inst}
    views.each do |view|
      close_results_view(view_viewer(view))    
    end
  end
  
  def open_results_view(viewer)
    view = viewer.view
    tabs = result_tab_pane
    set_view_viewer(view,viewer)
    if instance = viewer.instance
      tab_group = instance.__id__
    else
      tab_group = :global    
    end
    ntype = viewer.type.type
    tab_type = TypeTabMap[ntype] || ntype
    add_view_tab(tabs,view,viewer)
    @result_tabs[tab_group][tab_type] = viewer
    tabs.set_selected_component(view)
    show_search_results
  end

  def show_search_results
    @result_tab_pane.visible = true
    @results_select.selected = true
    adjust_right_splitter
  end

  def add_instance(instance)
    @instances[instance.address] = instance
    @main_tabs[instance.__id__] = {}
    @result_tabs[instance.__id__] = {}
    @instance_listeners.each do |lst|
      lst.instance_added(instance)    
    end
  end
  
  def remove_instance(inst)
    close_views_for_instance(inst)
    main_tree_model.remove_node_from_parent(inst.tree_node) if inst.tree_node
    @instances.delete(inst.address)
    @main_tabs.delete(inst.__id__)
    @result_tabs.delete(inst.__id__)
    @instance_listeners.each do |lst|
      lst.instance_removed(inst)    
    end
  end
  
  def add_instance_listener(lst)
    if InstanceListener === lst
      @instance_listeners << lst unless @instance_listeners.include?(lst)
    end
  end

  def remove_instance_listener(lst)
    @instance_listeners.delete(lst)  
  end
  
  def instance_list
    @instances.values.sort {|a,b| (a.name||a.address) <=> (b.name||b.address) }  
  end

  def viewer(type,subtype=nil)
    Viewers.viewer(type,subtype)  
  end
  
  def new_connection(port,name,host='localhost')
    raise ArgumentError,"invalid port: #{port}" unless (pnum = Integer(port) rescue nil)
    uri = "druby://#{host}:#{pnum}"
    # make sure we can connect before proceeding
    # TODO: need to wrap proxy for error handling
    proxy = nil
    begin
      proxy = DRbObject.new_with_uri(uri)
      proxy.ruby_version
    rescue
      JOptionPane.show_message_dialog(@main_frame,"Unable to connect to #{uri}")
      return
    end
    if (inst = @instances[uri])
      if inst.alive?
        rsp = JOptionPane.show_confirm_dialog(@main_frame,"Active connection exists for #{uri} - reset?")
        return unless rsp == JOptionPane::YES_OPTION
      end
      remove_instance(inst)
    end
    if proxy.respond_to?(:jruby_version)
      inst = JRubyInstance.new(proxy,name,uri)
    else
      inst = RubyInstance.new(proxy,name,uri)
    end
    add_instance(inst)
    
    new_node = nil
    root_tree_node do
      new_node = new_instance_node inst, :tree => @main_tree
    end
    new_node
  end

  def connection_dialog
    @connection_dialog ||= ConnectionDialog.new(self)  
  end
  
  def new_search(instance,clazz,var,value,gc=nil)
    raise Cheri.type_error(clazz,RubyInstance) unless RubyInstance === instance
    raise ArgumentError, "invalid class name #{clazz}" unless clazz =~ /^([A-Z])((\w|::[A-Z])*)$/
    raise ArgumentError, "invalid variable name #{var}" if var && var !~ /^([A-Za-z_])(\w*)$/
    var = ('@' + var).to_sym rescue nil if var
    if value
      if value =~ /^(\/)(.*)(\/)$/
        unless (val = Regexp.new($2) rescue nil)
          JOptionPane.show_message_dialog(@main_frame,"Invalid regular expression #{value}")
          return
        end
      else
        val = value
      end
    end
    if var || value
      nv = Cheri::Explorer::SearchNameValue.new(var,val)
      args = Cheri::Explorer::SearchArgs.new(clazz,[nv])
    else
      args = Cheri::Explorer::SearchArgs.new(clazz)
    end
    args.gc = true if gc
    @last_search = [instance,args]
    if (res = instance.proxy.find(args))
      results = Cheri::Explorer::SearchResults.new(args,res)
      vwr = viewer(:results).new(NodeTypes[:results],self,instance,results)
      open_results_view(vwr)
    end
  end
  
  def repeat_search
    if (last = @last_search)
      instance = last[0]
      args = last[1]  
      if (res = instance.proxy.find(args))
        results = Cheri::Explorer::SearchResults.new(args,res)
        vwr = viewer(:results).new(NodeTypes[:results],self,instance,results)
        open_results_view(vwr)
      end
    end
  end
  
  def new_find(instance,id,new_tab=nil)
    if rec = instance.proxy.object(id)
      ntv = case rec.clazz
        when 'Class' : NodeTypeValue.new(Class,rec.value,rec)
        when 'Module' : NodeTypeValue.new(Module,rec.value,rec)
        else NodeTypeValue.new(:object,rec.clazz,rec)
      end
      if (clazz = viewer(ntv.type,ntv.subtype))
        vwr = clazz.new(ntv,self,instance,ntv.value)
        view = vwr.view
        set_view_viewer(view,vwr)
        tabs = main_tab_pane
        add_view_tab(tabs,view,vwr)
        @main_tabs[instance.__id__][vwr.__id__] = vwr
        tabs.set_selected_component(view)
      else
        JOptionPane.show_message_dialog(@main_frame,"Unable to display object #{id} (no viewer)") 
      end
    else
      JOptionPane.show_message_dialog(@main_frame,"Unable to retrieve object #{id} (garbage-collected?)") 
    end
  end
  
  def show_linked_object(curvwr,id,new_tab=nil)
    instance = curvwr.instance
    unless rec = instance.proxy.object(id)
      JOptionPane.show_message_dialog(@main_frame,"Unable to retrieve object #{id} (garbage-collected?)") 
      return
    end
    ntv = case rec.clazz
      when 'Class' : NodeTypeValue.new(Class,rec.value,rec)
      when 'Module' : NodeTypeValue.new(Module,rec.value,rec)
      else NodeTypeValue.new(:object,rec.clazz,rec)
    end
    unless clazz = viewer(ntv.type,ntv.subtype)
      JOptionPane.show_message_dialog(@main_frame,"Unable to display object #{id} (no viewer)") 
    end
    vwr = clazz.new(ntv,self,instance,ntv.value)
    view = vwr.view
    set_view_viewer(view,vwr)
    tabs = main_tab_pane
    if new_tab
      add_view_tab(tabs,view,vwr)
      @main_tabs[instance.__id__][vwr.__id__] = vwr
    else
      ntype = vwr.type.type
      tab_type = TypeTabMap[ntype] || ntype
      current_viewer = @main_tabs[instance.__id__][tab_type]
      if current_viewer && (index = tabs.index(current_viewer.view))
        replace_view_tab(tabs,view,vwr,index)
      else
        add_view_tab(tabs,view,vwr)
      end
      @main_tabs[instance.__id__][tab_type] = vwr
    end
    tabs.set_selected_component(view)
  end

  def show_result_object(resvwr,id,new_tab=nil)
    instance = resvwr.instance
    unless rec = instance.proxy.object(id)
      JOptionPane.show_message_dialog(@main_frame,"Unable to retrieve object #{id} (garbage-collected?)") 
      return
    end
    ntv = case rec.clazz
      when 'Class' : NodeTypeValue.new(Class,rec.value,rec)
      when 'Module' : NodeTypeValue.new(Module,rec.value,rec)
      else NodeTypeValue.new(:object,rec.clazz,rec)
    end
    unless clazz = viewer(ntv.type,ntv.subtype)
      JOptionPane.show_message_dialog(@main_frame,"Unable to display object #{id} (no viewer)") 
    end
    vwr = clazz.new(ntv,self,instance,ntv.value)
    view = vwr.view
    set_view_viewer(view,vwr)
    tabs = main_tab_pane
    if new_tab
      add_view_tab(tabs,view,vwr)
      @main_tabs[instance.__id__][vwr.__id__] = vwr
    else
      current_viewer = @main_tabs[instance.__id__][resvwr.__id__]
      if current_viewer && (index = tabs.index(current_viewer.view))
        replace_view_tab(tabs,view,vwr,index)
      else
        add_view_tab(tabs,view,vwr)
      end
      @main_tabs[instance.__id__][resvwr.__id__] = vwr
    end
    tabs.set_selected_component(view)
  end
  
  def simple_value(instance,id)
    instance.proxy.simple_value(id) rescue 'Error'
  end

  def search_dialog
    @search_dialog ||= SearchDialog.new(self)  
  end

  def show_search_dialog
    search_dialog.show  
  end
  
  def about_dialog
    @about_dialog ||= AboutDialog.new(self)  
  end
  
  def show_about_dialog
    about_dialog.show  
  end

  def center(parent,child)
    x = parent.x + ((parent.width - child.width)/2)
    y = parent.y + ((parent.height - child.height)/2)
    child.set_location(x,y)
    child
  end


end #Main

class RubyInstance
  WeakHashMap = ::Java::JavaUtil::WeakHashMap

  def initialize(proxy,name,address)
    @proxy = proxy
    @name = name
    @addr = address
#    @viewers = WeakHashMap.new
  end
  def alive?
    @proxy.ruby_version rescue nil    
  end
  def proxy
    @proxy
  end
  def name
    @name || @addr
  end
  def name=(name)
    @name = name  
  end
  def address
    @addr  
  end
  def icon
    RubyIcon
  end
  def type
    :ruby_instance 
  end
#  def viewers
#    @viewers  
#  end
  def tree_node
    @node  
  end
  def tree_node=(node)
    @node = node  
  end

end #RubyInstance

class JRubyInstance < RubyInstance

  def icon
    JRubyIcon
  end

  def type
    :jruby_instance
  end
end #JRubyInstance


class ExplorerTreeNode < ::Java::javax.swing.tree.DefaultMutableTreeNode
  def initialize(viewer)
    super
    @viewer = viewer
  end
  def isLeaf
    @viewer.leaf?
  end
  def add(child)
    super
  end
  def viewer
    @viewer
  end
end #ExplorerTreeNode

class ExplorerTreeCellRenderer < ::Java::javax.swing.tree.DefaultTreeCellRenderer
  def getTreeCellRendererComponent(tree,node,sel,expanded,leaf,row,has_focus)
    super
    viewer = node.user_object
    set_text viewer.title_tree
    set_icon viewer.icon_tree if viewer.icon_tree
    self
  end
end #ExplorerTreeRenderer

module TabbedPaneMethods
  include Enumerable
  def views
    Array.new(tab_count) {|i| component_at(i) }
  end
  def each
    tab_count.times do |i|
      yield get_component_at(i)    
    end if block_given?
  end
  def include?(view)
    index_of_component(view) >= 0
  end
  def index(view)
    (ix = index_of_component(view)) >= 0 ? ix : nil
  end
  def [](ix)
    get_component_at(ix)
  end
  def []=(ix,view)
    set_component_at(ix,view)  
  end
  def []=(ix,v1,v2=nil)
    if v2
      case v1
        when :tab     : set_tab_component_at(ix,v2)
        when :title   : set_title_at(ix,v2)
        when :icon    : set_icon_at(ix,v2)
        when :tooltip : set_tool_tip_text_at(ix,v2)
      end
    else
      set_component_at(ix,v1)
    end
  end
  def active_view
    selected_component
  end
  def active_viewer
    if (view = selected_component)
      view.get_client_property(:viewer)
    end
  end
end #TabbedPaneMethods

class TabHistory
  def initialize(viewer)
    @h = [viewer]
    @c = 1
  end
  def <<(viewer)
    if (len = @h.length) > @c
      @h = @h[0,@c]
    end
    @h << viewer
    @c = @h.length
  end
  def curr
    @h[@c-1]
  end
  def next
    @h[@c]
  end
  def prev
    if @c >= 2 
      @h[@c-2]
    end
  end
  def next!
    if @c < @h.length
      v = @h[@c]
      @c += 1
      v
    end
  end
  def prev!
    if @c > 1
       @c -= 1
       @h[@c-1]
    end
  end
end #TabHistory


# TODO: may want JComponent version that uses get/put client property?
# TODO: had to do this, see note at set_view_viewer
#module ComponentViewMethods
#  def viewer
#    @viewer  
#  end
#  def viewer=(viewer)
#    @viewer = viewer  
#  end
#end #ComponentViewMethods


end #Explorer
end #JRuby
end #Cheri
