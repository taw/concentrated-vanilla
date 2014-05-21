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
module Swing
module Types
CJava = Cheri::Java #:nodoc:
JS = 'javax.swing.'.freeze #:nodoc:
class << self
  def get_class(sym)
    # TODO: threadsafe support?
    cls = @classes[sym]
    if cls
      if cls.instance_of?(String)
        cls = CJava.get_class(JS + cls)
        @classes[sym] = cls if cls
      end
      cls
    else
      nil
    end
  end
  def names
    @names ||= @classes.keys
  end
end #self
# TODO: review included classes; some of these would
# never be called in a builder context
@classes = {
  :action_map => 'ActionMap',
  :border_factory => 'BorderFactory',
  :box => 'Box',
  # handling box_layout in BoxComponentFactory to simplify syntax
  #  :box_layout => 'BoxLayout',
  :button_group => 'ButtonGroup',
  :cell_renderer_pane => 'CellRendererPane',
  :component_input_map => 'ComponentInputMap',
  :default_bounded_range_model => 'DefaultBoundedRangeModel',
  :default_button_model => 'DefaultButtonModel',
  :default_cell_editor => 'DefaultCellEditor',
  :default_combo_box_model => 'DefaultComboBoxModel',
  :default_desktop_manager => 'DefaultDesktopManager',
  :default_focus_manager => 'DefaultFocusManager',
  :default_list_cell_renderer => 'DefaultListCellRenderer',
  :default_list_cell_renderer_ui_resource => 'DefaultListCellRenderer::UIResource',
  :default_list_model => 'DefaultListModel',
  :default_list_selection_model => 'DefaultListSelectionModel',
  :default_row_sorter => 'DefaultRowSorter',
  :default_row_sorter_model_wrapper => 'DefaultRowSorter::ModelWrapper',
  :default_single_selection_model => 'DefaultSingleSelectionModel',
  :focus_manager => 'FocusManager',
  :gray_filter => 'GrayFilter',
  :group_layout => 'GroupLayout',
  :image_icon => 'ImageIcon',
  :input_map => 'InputMap',
  :input_verifier => 'InputVerifier',
  :internal_frame_focus_traversal_policy => 'InternalFrameFocusTraversalPolicy',
  :j_applet => 'JApplet',
  :applet => 'JApplet',
  :j_button => 'JButton',
  :button => 'JButton',
  :j_check_box => 'JCheckBox',
  :check_box => 'JCheckBox',
  :j_check_box_menu_item => 'JCheckBoxMenuItem',
  :check_box_menu_item => 'JCheckBoxMenuItem',
  :j_color_chooser => 'JColorChooser',
  :color_chooser => 'JColorChooser',
  :j_combo_box => 'JComboBox',
  :combo_box => 'JComboBox',
  :j_component => 'JComponent',
  :component => 'JComponent',
  :j_desktop_pane => 'JDesktopPane',
  :desktop_pane => 'JDesktopPane',
  :j_dialog => 'JDialog',
  :dialog => 'JDialog',
  :j_editor_pane => 'JEditorPane',
  :editor_pane => 'JEditorPane',
  :j_file_chooser => 'JFileChooser',
  :file_chooser => 'JFileChooser',
  :j_formatted_text_field => 'JFormattedTextField',
  :formatted_text_field => 'JFormattedTextField',
  :j_frame => 'JFrame',
  :frame => 'JFrame',
  :j_internal_frame => 'JInternalFrame',
  :internal_frame => 'JInternalFrame',
  :j_internal_frame_desktop_icon => 'JInternalFrame::JDesktopIcon',
  :internal_frame_desktop_icon => 'JInternalFrame::JDesktopIcon',
  :j_label => 'JLabel',
  :label => 'JLabel',
  :j_layered_pane => 'JLayeredPane',
  :layered_pane => 'JLayeredPane',
  :j_list => 'JList',
  :list => 'JList',
  :j_list_drop_location => 'JList::DropLocation',
  :list_drop_location => 'JList::DropLocation',
  :j_menu => 'JMenu',
  :menu => 'JMenu',
  :j_menu_bar => 'JMenuBar',
  :menu_bar => 'JMenuBar',
  :j_menu_item => 'JMenuItem',
  :menu_item => 'JMenuItem',
  :j_option_pane => 'JOptionPane',
  :option_pane => 'JOptionPane',
  :j_panel => 'JPanel',
  :panel => 'JPanel',
  :j_password_field => 'JPasswordField',
  :password_field => 'JPasswordField',
  :j_popup_menu => 'JPopupMenu',
  :popup_menu => 'JPopupMenu',
  :j_popup_menu_separator => 'JPopupMenu::Separator',
  :popup_menu_separator => 'JPopupMenu::Separator',
  :j_progress_bar => 'JProgressBar',
  :progress_bar => 'JProgressBar',
  :j_radio_button => 'JRadioButton',
  :radio_button => 'JRadioButton',
  :j_radio_button_menu_item => 'JRadioButtonMenuItem',
  :radio_button_menu_item => 'JRadioButtonMenuItem',
  :j_root_pane => 'JRootPane',
  :root_pane => 'JRootPane',
  :j_scroll_bar => 'JScrollBar',
  :scroll_bar => 'JScrollBar',
  :j_scroll_pane => 'JScrollPane',
  :scroll_pane => 'JScrollPane',
  :j_separator => 'JSeparator',
  :separator => 'JSeparator',
  :j_slider => 'JSlider',
  :slider => 'JSlider',
  :j_spinner => 'JSpinner',
  :spinner => 'JSpinner',
  :j_spinner_date_editor => 'JSpinner::DateEditor',
  :spinner_date_editor => 'JSpinner::DateEditor',
  :j_spinner_default_editor => 'JSpinner::DefaultEditor',
  :spinner_default_editor => 'JSpinner::DefaultEditor',
  :j_spinner_list_editor => 'JSpinner::ListEditor',
  :spinner_list_editor => 'JSpinner::ListEditor',
  :j_spinner_number_editor => 'JSpinner::NumberEditor',
  :spinner_number_editor => 'JSpinner::NumberEditor',
  :j_split_pane => 'JSplitPane',
  :split_pane => 'JSplitPane',
  :j_tabbed_pane => 'JTabbedPane',
  :tabbed_pane => 'JTabbedPane',
  :j_table => 'JTable',
  :table => 'JTable',
  :j_table_drop_location => 'JTable::DropLocation',
  :table_drop_location => 'JTable::DropLocation',
  :j_text_area => 'JTextArea',
  :text_area => 'JTextArea',
  :j_text_field => 'JTextField',
  :text_field => 'JTextField',
  :j_text_pane => 'JTextPane',
  :text_pane => 'JTextPane',
  :j_toggle_button => 'JToggleButton',
  :toggle_button => 'JToggleButton',
  :j_toggle_button_toggle_button_model => 'JToggleButton::ToggleButtonModel',
  :toggle_button_toggle_button_model => 'JToggleButton::ToggleButtonModel',
  :toggle_button_model => 'JToggleButton::ToggleButtonModel',
  :j_tool_bar => 'JToolBar',
  :tool_bar => 'JToolBar',
  :j_tool_bar_separator => 'JToolBar::Separator',
  :tool_bar_separator => 'JToolBar::Separator',
  :j_tool_tip => 'JToolTip',
  :tool_tip => 'JToolTip',
  :j_tree => 'JTree',
  :tree => 'JTree',
  :j_tree_drop_location => 'JTree::DropLocation',
  :tree_drop_location => 'JTree::DropLocation',
  :j_tree_dynamic_util_tree_node => 'JTree::DynamicUtilTreeNode',
  :tree_dynamic_util_tree_node => 'JTree::DynamicUtilTreeNode',
  :dynamic_util_tree_node => 'JTree::DynamicUtilTreeNode',
  :j_tree_empty_selection_model => 'JTree::EmptySelectionModel',
  :tree_empty_selection_model => 'JTree::EmptySelectionModel',
  :j_viewport => 'JViewport',
  :viewport => 'JViewport',
  :j_window => 'JWindow',
  :window => 'JWindow',
  :key_stroke => 'KeyStroke',
  :layout_focus_traversal_policy => 'LayoutFocusTraversalPolicy',
  :layout_style => 'LayoutStyle',
  :look_and_feel => 'LookAndFeel',
  :menu_selection_manager => 'MenuSelectionManager',
  :overlay_layout => 'OverlayLayout',
  :popup => 'Popup',
  :popup_factory => 'PopupFactory',
  :progress_monitor => 'ProgressMonitor',
  :progress_monitor_input_stream => 'ProgressMonitorInputStream',
  :repaint_manager => 'RepaintManager',
  :row_filter => 'RowFilter',
  :row_filter_entry => 'RowFilter::Entry ',
  :row_sorter => 'RowSorter',
  :row_sorter_sort_key => 'RowSorter::SortKey',
  :scroll_pane_layout => 'ScrollPaneLayout',
  :scroll_pane_layout_ui_resource => 'ScrollPaneLayout::UIResource',
  :size_requirements => 'SizeRequirements',
  :size_sequence => 'SizeSequence',
  :sorting_focus_traversal_policy => 'SortingFocusTraversalPolicy',
  :spinner_date_model => 'SpinnerDateModel',
  :spinner_list_model => 'SpinnerListModel',
  :spinner_number_model => 'SpinnerNumberModel',
  :spring => 'Spring',
  :spring_layout => 'SpringLayout',
  :spring_layout_constraints => 'SpringLayout::Constraints',
  :swing_utilities => 'SwingUtilities',
  :swing_worker => 'SwingWorker',
  :timer => 'Timer',
  :tool_tip_manager => 'ToolTipManager',
  :transfer_handler => 'TransferHandler',
  :transfer_handler_drop_location => 'TransferHandler::DropLocation',
  :transfer_handler_transfer_support => 'TransferHandler::TransferSupport',
  :ui_defaults => 'UIDefaults',
  :ui_defaults_lazy_input_map => 'UIDefaults::LazyInputMap',
  :ui_defaults_proxy_lazy_value => 'UIDefaults::ProxyLazyValue',
  :ui_manager => 'UIManager',
  :ui_manager_look_and_feel_info => 'UIManager::LookAndFeelInfo',
  :viewport_layout => 'ViewportLayout',
  :bevel_border => 'border.BevelBorder',
  :compound_border => 'border.CompoundBorder',
  :empty_border => 'border.EmptyBorder',
  :etched_border => 'border.EtchedBorder',
  :line_border => 'border.LineBorder',
  :matte_border => 'border.MatteBorder',
  :soft_bevel_border => 'border.SoftBevelBorder',
  :titled_border => 'border.TitledBorder',
  :color_chooser_component_factory => 'colorchooser.ColorChooserComponentFactory',
  :default_color_selection_model => 'colorchooser.DefaultColorSelectionModel',
  :file_name_extension_filter => 'filechooser.FileNameExtensionFilter',
  :default_table_cell_renderer => 'table.DefaultTableCellRenderer',
  :default_table_cell_renderer_ui_resource => 'table.DefaultTableCellRenderer::UIResource',
  :default_table_column_model => 'table.DefaultTableColumnModel',
  :default_table_model => 'table.DefaultTableModel',
  :j_table_header => 'table.JTableHeader',
  :table_header => 'table.JTableHeader',
  :table_column => 'table.TableColumn',
  :table_row_sorter => 'table.TableRowSorter',
  :default_mutable_tree_node => 'tree.DefaultMutableTreeNode',
  :default_tree_cell_editor => 'tree.DefaultTreeCellEditor',
  :default_tree_cell_renderer => 'tree.DefaultTreeCellRenderer',
  :default_tree_model => 'tree.DefaultTreeModel',
  :default_tree_selection_model => 'tree.DefaultTreeSelectionModel',
  :fixed_height_layout_cache => 'tree.FixedHeightLayoutCache',
  :tree_path => 'tree.TreePath',
  :variable_height_layout_cache => 'tree.VariableHeightLayoutCache'
}

end #StandardTypes
end #Swing
end #Cheri

#cls = Cheri::Swing::StandardTypes.get_class(:frame)
#puts cls.java_class.name
