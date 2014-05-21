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
module Constants
ConstRec = Cheri::Java::Builder::Constants::ConstRec
@constants = {}
class << self
  
  def add(y,t,d) #:nodoc:
    unless (@constants[y])
      @constants[y] = ConstRec.new(t,d)
      return
    end
    r = @constants[y]
    r = r.next_rec while r.next_rec
    r.next_rec = ConstRec.new(t,d)
  end

  # call-seq:
  #   Constants.get(symbol)             -> ConstRec or nil
  #   Constants.get_const_recs(symbol)  -> ConstRec or nil
  #   
  def get(y)
    @constants[y]
  end
  alias_method :get_const_recs, :get

end #self
int = 'int'
integer = 'java.lang.Integer'
string = 'java.lang.String'
object = 'java.lang.Object'

decl_cls = 'javax.swing.SwingConstants'
add(:CENTER,int,decl_cls)
add(:TOP,int,decl_cls)
add(:LEFT,int,decl_cls)
add(:BOTTOM,int,decl_cls)
add(:RIGHT,int,decl_cls)
add(:NORTH,int,decl_cls)
add(:NORTH_EAST,int,decl_cls)
add(:EAST,int,decl_cls)
add(:SOUTH_EAST,int,decl_cls)
add(:SOUTH,int,decl_cls)
add(:SOUTH_WEST,int,decl_cls)
add(:WEST,int,decl_cls)
add(:NORTH_WEST,int,decl_cls)
add(:HORIZONTAL,int,decl_cls)
add(:VERTICAL,int,decl_cls)
add(:LEADING,int,decl_cls)
add(:TRAILING,int,decl_cls)
add(:NEXT,int,decl_cls)
add(:PREVIOUS,int,decl_cls)
decl_cls = 'javax.swing.WindowConstants'
add(:DO_NOTHING_ON_CLOSE,int,decl_cls)
add(:HIDE_ON_CLOSE,int,decl_cls)
add(:DISPOSE_ON_CLOSE,int,decl_cls)
add(:EXIT_ON_CLOSE,int,decl_cls)
decl_cls = 'javax.swing.ScrollPaneConstants'
add(:VIEWPORT,string,decl_cls)
add(:VERTICAL_SCROLLBAR,string,decl_cls)
add(:HORIZONTAL_SCROLLBAR,string,decl_cls)
add(:ROW_HEADER,string,decl_cls)
add(:COLUMN_HEADER,string,decl_cls)
add(:LOWER_LEFT_CORNER,string,decl_cls)
add(:LOWER_RIGHT_CORNER,string,decl_cls)
add(:UPPER_LEFT_CORNER,string,decl_cls)
add(:UPPER_RIGHT_CORNER,string,decl_cls)
add(:LOWER_LEADING_CORNER,string,decl_cls)
add(:LOWER_TRAILING_CORNER,string,decl_cls)
add(:UPPER_LEADING_CORNER,string,decl_cls)
add(:UPPER_TRAILING_CORNER,string,decl_cls)
add(:VERTICAL_SCROLLBAR_POLICY,string,decl_cls)
add(:HORIZONTAL_SCROLLBAR_POLICY,string,decl_cls)
add(:VERTICAL_SCROLLBAR_AS_NEEDED,int,decl_cls)
add(:VERTICAL_SCROLLBAR_NEVER,int,decl_cls)
add(:VERTICAL_SCROLLBAR_ALWAYS,int,decl_cls)
add(:HORIZONTAL_SCROLLBAR_AS_NEEDED,int,decl_cls)
add(:HORIZONTAL_SCROLLBAR_NEVER,int,decl_cls)
add(:HORIZONTAL_SCROLLBAR_ALWAYS,int,decl_cls)
decl_cls = 'javax.swing.JComponent'
add(:WHEN_FOCUSED,int,decl_cls)
add(:WHEN_ANCESTOR_OF_FOCUSED_COMPONENT,int,decl_cls)
add(:WHEN_IN_FOCUSED_WINDOW,int,decl_cls)
add(:UNDEFINED_CONDITION,int,decl_cls)
add(:TOOL_TIP_TEXT_KEY,string,decl_cls)
decl_cls = 'javax.swing.BoxLayout'
add(:X_AXIS,int,decl_cls)
add(:Y_AXIS,int,decl_cls)
add(:LINE_AXIS,int,decl_cls)
add(:PAGE_AXIS,int,decl_cls)
decl_cls = 'javax.swing.JOptionPane'
add(:UNINITIALIZED_VALUE,object,decl_cls)
add(:DEFAULT_OPTION,int,decl_cls)
add(:YES_NO_OPTION,int,decl_cls)
add(:YES_NO_CANCEL_OPTION,int,decl_cls)
add(:OK_CANCEL_OPTION,int,decl_cls)
add(:YES_OPTION,int,decl_cls)
add(:NO_OPTION,int,decl_cls)
add(:CANCEL_OPTION,int,decl_cls)
add(:OK_OPTION,int,decl_cls)
add(:CLOSED_OPTION,int,decl_cls)
add(:ERROR_MESSAGE,int,decl_cls)
add(:INFORMATION_MESSAGE,int,decl_cls)
add(:WARNING_MESSAGE,int,decl_cls)
add(:QUESTION_MESSAGE,int,decl_cls)
add(:PLAIN_MESSAGE,int,decl_cls)
add(:ICON_PROPERTY,string,decl_cls)
add(:MESSAGE_PROPERTY,string,decl_cls)
add(:VALUE_PROPERTY,string,decl_cls)
add(:OPTIONS_PROPERTY,string,decl_cls)
add(:INITIAL_VALUE_PROPERTY,string,decl_cls)
add(:MESSAGE_TYPE_PROPERTY,string,decl_cls)
add(:OPTION_TYPE_PROPERTY,string,decl_cls)
add(:SELECTION_VALUES_PROPERTY,string,decl_cls)
add(:INITIAL_SELECTION_VALUE_PROPERTY,string,decl_cls)
add(:INPUT_VALUE_PROPERTY,string,decl_cls)
add(:WANTS_INPUT_PROPERTY,string,decl_cls)
decl_cls = 'javax.swing.Action'
add(:DEFAULT,string,decl_cls)
add(:NAME,string,decl_cls)
add(:SHORT_DESCRIPTION,string,decl_cls)
add(:LONG_DESCRIPTION,string,decl_cls)
add(:SMALL_ICON,string,decl_cls)
add(:ACTION_COMMAND_KEY,string,decl_cls)
add(:ACCELERATOR_KEY,string,decl_cls)
add(:MNEMONIC_KEY,string,decl_cls)
add(:SELECTED_KEY,string,decl_cls)
add(:DISPLAYED_MNEMONIC_INDEX_KEY,string,decl_cls)
add(:LARGE_ICON_KEY,string,decl_cls)
decl_cls = 'javax.swing.ListSelectionModel'
add(:SINGLE_SELECTION,int,decl_cls)
add(:SINGLE_INTERVAL_SELECTION,int,decl_cls)
add(:MULTIPLE_INTERVAL_SELECTION,int,decl_cls)
decl_cls = 'javax.swing.AbstractButton'
add(:MODEL_CHANGED_PROPERTY,string,decl_cls)
add(:TEXT_CHANGED_PROPERTY,string,decl_cls)
add(:MNEMONIC_CHANGED_PROPERTY,string,decl_cls)
add(:MARGIN_CHANGED_PROPERTY,string,decl_cls)
add(:VERTICAL_ALIGNMENT_CHANGED_PROPERTY,string,decl_cls)
add(:HORIZONTAL_ALIGNMENT_CHANGED_PROPERTY,string,decl_cls)
add(:VERTICAL_TEXT_POSITION_CHANGED_PROPERTY,string,decl_cls)
add(:HORIZONTAL_TEXT_POSITION_CHANGED_PROPERTY,string,decl_cls)
add(:BORDER_PAINTED_CHANGED_PROPERTY,string,decl_cls)
add(:FOCUS_PAINTED_CHANGED_PROPERTY,string,decl_cls)
add(:ROLLOVER_ENABLED_CHANGED_PROPERTY,string,decl_cls)
add(:CONTENT_AREA_FILLED_CHANGED_PROPERTY,string,decl_cls)
add(:ICON_CHANGED_PROPERTY,string,decl_cls)
add(:PRESSED_ICON_CHANGED_PROPERTY,string,decl_cls)
add(:SELECTED_ICON_CHANGED_PROPERTY,string,decl_cls)
add(:ROLLOVER_ICON_CHANGED_PROPERTY,string,decl_cls)
add(:ROLLOVER_SELECTED_ICON_CHANGED_PROPERTY,string,decl_cls)
add(:DISABLED_ICON_CHANGED_PROPERTY,string,decl_cls)
add(:DISABLED_SELECTED_ICON_CHANGED_PROPERTY,string,decl_cls)
decl_cls = 'javax.swing.DebugGraphics'
add(:LOG_OPTION,int,decl_cls)
add(:FLASH_OPTION,int,decl_cls)
add(:BUFFERED_OPTION,int,decl_cls)
add(:NONE_OPTION,int,decl_cls)
decl_cls = 'javax.swing.DefaultButtonModel'
add(:ARMED,int,decl_cls)
add(:SELECTED,int,decl_cls)
add(:PRESSED,int,decl_cls)
add(:ENABLED,int,decl_cls)
add(:ROLLOVER,int,decl_cls)
decl_cls = 'javax.swing.FocusManager'
add(:FOCUS_MANAGER_CLASS_PROPERTY,string,decl_cls)
add(:FORWARD_TRAVERSAL_KEYS,int,decl_cls)
add(:BACKWARD_TRAVERSAL_KEYS,int,decl_cls)
add(:UP_CYCLE_TRAVERSAL_KEYS,int,decl_cls)
add(:DOWN_CYCLE_TRAVERSAL_KEYS,int,decl_cls)
decl_cls = 'javax.swing.GroupLayout'
add(:DEFAULT_SIZE,int,decl_cls)
add(:PREFERRED_SIZE,int,decl_cls)
decl_cls = 'javax.swing.JCheckBox'
add(:BORDER_PAINTED_FLAT_CHANGED_PROPERTY,string,decl_cls)
decl_cls = 'javax.swing.JColorChooser'
add(:SELECTION_MODEL_PROPERTY,string,decl_cls)
add(:PREVIEW_PANEL_PROPERTY,string,decl_cls)
add(:CHOOSER_PANELS_PROPERTY,string,decl_cls)
decl_cls = 'javax.swing.JDesktopPane'
add(:LIVE_DRAG_MODE,int,decl_cls)
add(:OUTLINE_DRAG_MODE,int,decl_cls)
decl_cls = 'javax.swing.JEditorPane'
add(:W3C_LENGTH_UNITS,string,decl_cls)
add(:HONOR_DISPLAY_PROPERTIES,string,decl_cls)
decl_cls = 'javax.swing.JFileChooser'
add(:OPEN_DIALOG,int,decl_cls)
add(:SAVE_DIALOG,int,decl_cls)
add(:CUSTOM_DIALOG,int,decl_cls)
add(:CANCEL_OPTION,int,decl_cls)
add(:APPROVE_OPTION,int,decl_cls)
add(:ERROR_OPTION,int,decl_cls)
add(:FILES_ONLY,int,decl_cls)
add(:DIRECTORIES_ONLY,int,decl_cls)
add(:FILES_AND_DIRECTORIES,int,decl_cls)
add(:CANCEL_SELECTION,string,decl_cls)
add(:APPROVE_SELECTION,string,decl_cls)
add(:APPROVE_BUTTON_TEXT_CHANGED_PROPERTY,string,decl_cls)
add(:APPROVE_BUTTON_TOOL_TIP_TEXT_CHANGED_PROPERTY,string,decl_cls)
add(:APPROVE_BUTTON_MNEMONIC_CHANGED_PROPERTY,string,decl_cls)
add(:CONTROL_BUTTONS_ARE_SHOWN_CHANGED_PROPERTY,string,decl_cls)
add(:DIRECTORY_CHANGED_PROPERTY,string,decl_cls)
add(:SELECTED_FILE_CHANGED_PROPERTY,string,decl_cls)
add(:SELECTED_FILES_CHANGED_PROPERTY,string,decl_cls)
add(:MULTI_SELECTION_ENABLED_CHANGED_PROPERTY,string,decl_cls)
add(:FILE_SYSTEM_VIEW_CHANGED_PROPERTY,string,decl_cls)
add(:FILE_VIEW_CHANGED_PROPERTY,string,decl_cls)
add(:FILE_HIDING_CHANGED_PROPERTY,string,decl_cls)
add(:FILE_FILTER_CHANGED_PROPERTY,string,decl_cls)
add(:FILE_SELECTION_MODE_CHANGED_PROPERTY,string,decl_cls)
add(:ACCESSORY_CHANGED_PROPERTY,string,decl_cls)
add(:ACCEPT_ALL_FILE_FILTER_USED_CHANGED_PROPERTY,string,decl_cls)
add(:DIALOG_TITLE_CHANGED_PROPERTY,string,decl_cls)
add(:DIALOG_TYPE_CHANGED_PROPERTY,string,decl_cls)
add(:CHOOSABLE_FILE_FILTER_CHANGED_PROPERTY,string,decl_cls)
decl_cls = 'javax.swing.JFormattedTextField'
add(:COMMIT,int,decl_cls)
add(:COMMIT_OR_REVERT,int,decl_cls)
add(:REVERT,int,decl_cls)
add(:PERSIST,int,decl_cls)
decl_cls = 'javax.swing.JFrame'
add(:EXIT_ON_CLOSE,int,decl_cls)
decl_cls = 'javax.swing.JInternalFrame'
add(:CONTENT_PANE_PROPERTY,string,decl_cls)
add(:MENU_BAR_PROPERTY,string,decl_cls)
add(:TITLE_PROPERTY,string,decl_cls)
add(:LAYERED_PANE_PROPERTY,string,decl_cls)
add(:ROOT_PANE_PROPERTY,string,decl_cls)
add(:GLASS_PANE_PROPERTY,string,decl_cls)
add(:FRAME_ICON_PROPERTY,string,decl_cls)
add(:IS_SELECTED_PROPERTY,string,decl_cls)
add(:IS_CLOSED_PROPERTY,string,decl_cls)
add(:IS_MAXIMUM_PROPERTY,string,decl_cls)
add(:IS_ICON_PROPERTY,string,decl_cls)
decl_cls = 'javax.swing.JLayeredPane'
add(:DEFAULT_LAYER,integer,decl_cls)
add(:PALETTE_LAYER,integer,decl_cls)
add(:MODAL_LAYER,integer,decl_cls)
add(:POPUP_LAYER,integer,decl_cls)
add(:DRAG_LAYER,integer,decl_cls)
add(:FRAME_CONTENT_LAYER,integer,decl_cls)
add(:LAYER_PROPERTY,string,decl_cls)
decl_cls = 'javax.swing.JList'
add(:VERTICAL,int,decl_cls)
add(:VERTICAL_WRAP,int,decl_cls)
add(:HORIZONTAL_WRAP,int,decl_cls)
decl_cls = 'javax.swing.JRootPane'
add(:NONE,int,decl_cls)
add(:FRAME,int,decl_cls)
add(:PLAIN_DIALOG,int,decl_cls)
add(:INFORMATION_DIALOG,int,decl_cls)
add(:ERROR_DIALOG,int,decl_cls)
add(:COLOR_CHOOSER_DIALOG,int,decl_cls)
add(:FILE_CHOOSER_DIALOG,int,decl_cls)
add(:QUESTION_DIALOG,int,decl_cls)
decl_cls = 'javax.swing.JSplitPane'
add(:VERTICAL_SPLIT,int,decl_cls)
add(:HORIZONTAL_SPLIT,int,decl_cls)
add(:LEFT,string,decl_cls)
add(:RIGHT,string,decl_cls)
add(:TOP,string,decl_cls)
add(:BOTTOM,string,decl_cls)
add(:DIVIDER,string,decl_cls)
add(:ORIENTATION_PROPERTY,string,decl_cls)
add(:CONTINUOUS_LAYOUT_PROPERTY,string,decl_cls)
add(:DIVIDER_SIZE_PROPERTY,string,decl_cls)
add(:ONE_TOUCH_EXPANDABLE_PROPERTY,string,decl_cls)
add(:LAST_DIVIDER_LOCATION_PROPERTY,string,decl_cls)
add(:DIVIDER_LOCATION_PROPERTY,string,decl_cls)
add(:RESIZE_WEIGHT_PROPERTY,string,decl_cls)
decl_cls = 'javax.swing.JTabbedPane'
add(:WRAP_TAB_LAYOUT,int,decl_cls)
add(:SCROLL_TAB_LAYOUT,int,decl_cls)
decl_cls = 'javax.swing.JTable'
add(:AUTO_RESIZE_OFF,int,decl_cls)
add(:AUTO_RESIZE_NEXT_COLUMN,int,decl_cls)
add(:AUTO_RESIZE_SUBSEQUENT_COLUMNS,int,decl_cls)
add(:AUTO_RESIZE_LAST_COLUMN,int,decl_cls)
add(:AUTO_RESIZE_ALL_COLUMNS,int,decl_cls)
decl_cls = 'javax.swing.JTextField'
add(:NotifyAction,string,decl_cls)
decl_cls = 'javax.swing.JTree'
add(:CELL_RENDERER_PROPERTY,string,decl_cls)
add(:TREE_MODEL_PROPERTY,string,decl_cls)
add(:ROOT_VISIBLE_PROPERTY,string,decl_cls)
add(:SHOWS_ROOT_HANDLES_PROPERTY,string,decl_cls)
add(:ROW_HEIGHT_PROPERTY,string,decl_cls)
add(:CELL_EDITOR_PROPERTY,string,decl_cls)
add(:EDITABLE_PROPERTY,string,decl_cls)
add(:LARGE_MODEL_PROPERTY,string,decl_cls)
add(:SELECTION_MODEL_PROPERTY,string,decl_cls)
add(:VISIBLE_ROW_COUNT_PROPERTY,string,decl_cls)
add(:INVOKES_STOP_CELL_EDITING_PROPERTY,string,decl_cls)
add(:SCROLLS_ON_EXPAND_PROPERTY,string,decl_cls)
add(:TOGGLE_CLICK_COUNT_PROPERTY,string,decl_cls)
add(:LEAD_SELECTION_PATH_PROPERTY,string,decl_cls)
add(:ANCHOR_SELECTION_PATH_PROPERTY,string,decl_cls)
add(:EXPANDS_SELECTED_PATHS_PROPERTY,string,decl_cls)
decl_cls = 'javax.swing.JViewport'
add(:BLIT_SCROLL_MODE,int,decl_cls)
add(:BACKINGSTORE_SCROLL_MODE,int,decl_cls)
add(:SIMPLE_SCROLL_MODE,int,decl_cls)
decl_cls = 'javax.swing.Spring'
add(:UNSET,int,decl_cls)
decl_cls = 'javax.swing.SpringLayout'
add(:NORTH,string,decl_cls)
add(:SOUTH,string,decl_cls)
add(:EAST,string,decl_cls)
add(:WEST,string,decl_cls)
add(:HORIZONTAL_CENTER,string,decl_cls)
add(:VERTICAL_CENTER,string,decl_cls)
add(:BASELINE,string,decl_cls)
add(:WIDTH,string,decl_cls)
add(:HEIGHT,string,decl_cls)
decl_cls = 'javax.swing.TransferHandler'
add(:NONE,int,decl_cls)
add(:COPY,int,decl_cls)
add(:MOVE,int,decl_cls)
add(:COPY_OR_MOVE,int,decl_cls)
add(:LINK,int,decl_cls)
decl_cls = 'javax.swing.border.BevelBorder'
add(:RAISED,int,decl_cls)
add(:LOWERED,int,decl_cls)
decl_cls = 'javax.swing.border.EtchedBorder'
add(:RAISED,int,decl_cls)
add(:LOWERED,int,decl_cls)
decl_cls = 'javax.swing.border.TitledBorder'
add(:DEFAULT_POSITION,int,decl_cls)
add(:ABOVE_TOP,int,decl_cls)
add(:TOP,int,decl_cls)
add(:BELOW_TOP,int,decl_cls)
add(:ABOVE_BOTTOM,int,decl_cls)
add(:BOTTOM,int,decl_cls)
add(:BELOW_BOTTOM,int,decl_cls)
add(:DEFAULT_JUSTIFICATION,int,decl_cls)
add(:LEFT,int,decl_cls)
add(:CENTER,int,decl_cls)
add(:RIGHT,int,decl_cls)
add(:LEADING,int,decl_cls)
add(:TRAILING,int,decl_cls)
decl_cls = 'javax.swing.event.AncestorEvent'
add(:ANCESTOR_ADDED,int,decl_cls)
add(:ANCESTOR_REMOVED,int,decl_cls)
add(:ANCESTOR_MOVED,int,decl_cls)
decl_cls = 'javax.swing.event.DocumentEvent::EventType'
add(:INSERT,'javax.swing.event.DocumentEvent$EventType',decl_cls)
add(:REMOVE,'javax.swing.event.DocumentEvent$EventType',decl_cls)
add(:CHANGE,'javax.swing.event.DocumentEvent$EventType',decl_cls)
decl_cls = 'javax.swing.event.HyperlinkEvent::EventType'
add(:ENTERED,'javax.swing.event.HyperlinkEvent$EventType',decl_cls)
add(:EXITED,'javax.swing.event.HyperlinkEvent$EventType',decl_cls)
add(:ACTIVATED,'javax.swing.event.HyperlinkEvent$EventType',decl_cls)
decl_cls = 'javax.swing.event.InternalFrameEvent'
add(:INTERNAL_FRAME_FIRST,int,decl_cls)
add(:INTERNAL_FRAME_LAST,int,decl_cls)
add(:INTERNAL_FRAME_OPENED,int,decl_cls)
add(:INTERNAL_FRAME_CLOSING,int,decl_cls)
add(:INTERNAL_FRAME_CLOSED,int,decl_cls)
add(:INTERNAL_FRAME_ICONIFIED,int,decl_cls)
add(:INTERNAL_FRAME_DEICONIFIED,int,decl_cls)
add(:INTERNAL_FRAME_ACTIVATED,int,decl_cls)
add(:INTERNAL_FRAME_DEACTIVATED,int,decl_cls)
decl_cls = 'javax.swing.event.ListDataEvent'
add(:CONTENTS_CHANGED,int,decl_cls)
add(:INTERVAL_ADDED,int,decl_cls)
add(:INTERVAL_REMOVED,int,decl_cls)
decl_cls = 'javax.swing.event.TableModelEvent'
add(:INSERT,int,decl_cls)
add(:UPDATE,int,decl_cls)
add(:DELETE,int,decl_cls)
add(:HEADER_ROW,int,decl_cls)
add(:ALL_COLUMNS,int,decl_cls)
decl_cls = 'javax.swing.event.RowSorterEvent::Type'
add(:SORT_ORDER_CHANGED,'javax.swing.event.RowSorterEvent$Type',decl_cls)
add(:SORTED,'javax.swing.event.RowSorterEvent$Type',decl_cls)
decl_cls = 'javax.swing.table.TableColumn'
add(:COLUMN_WIDTH_PROPERTY,string,decl_cls)
add(:HEADER_VALUE_PROPERTY,string,decl_cls)
add(:HEADER_RENDERER_PROPERTY,string,decl_cls)
add(:CELL_RENDERER_PROPERTY,string,decl_cls)
decl_cls = 'javax.swing.tree.TreeSelectionModel'
add(:SINGLE_TREE_SELECTION,int,decl_cls)
add(:CONTIGUOUS_TREE_SELECTION,int,decl_cls)
add(:DISCONTIGUOUS_TREE_SELECTION,int,decl_cls)
decl_cls = 'javax.swing.tree.DefaultMutableTreeNode'
add(:EMPTY_ENUMERATION,'java.util.Enumeration',decl_cls)
decl_cls = 'javax.swing.tree.DefaultTreeSelectionModel'
add(:SELECTION_MODE_PROPERTY,string,decl_cls)
add(:SINGLE_TREE_SELECTION,int,decl_cls)
add(:CONTIGUOUS_TREE_SELECTION,int,decl_cls)
add(:DISCONTIGUOUS_TREE_SELECTION,int,decl_cls)
decl_cls = 'javax.swing.undo.StateEditable'
add(:RCSID,string,decl_cls)
end #StandardConstants
end #Swing
end #Cheri
