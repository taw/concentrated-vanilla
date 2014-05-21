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
module Swing

# note: inherits connection types from AWTConnecter
SwingConnecter = Cheri::Builder::TypeConnecter.new(Cheri::AWT::AWTConnecter) do
  jver = ENV_JAVA['java.version']
  Java5 = String === jver && jver >= '1.5'
  Java6 = String === jver && jver >= '1.6'
  S = java.lang.String.new ''
  TreePath = javax.swing.tree.TreePath
  GridBagConstraints = java.awt.GridBagConstraints
  GridTableLayout = org.cheri.swing.layout.GridTableLayout
  
  type javax.swing.JComponent do
    connect javax.swing.border.Border, :setBorder
  end

  type javax.swing.AbstractButton do
    connect javax.swing.Action, :setAction
    connect javax.swing.ButtonModel, :setModel
    connect javax.swing.Icon, :setIcon  
  end

  type javax.swing.ButtonGroup do
    # TODO: see what happens if a JCheckBox is added - should try to
    # allow user JToggleButton subclasses
    connect javax.swing.JRadioButton, :add
    connect javax.swing.JRadioButtonMenuItem, :add  
  end

  type [javax.swing.JApplet,
       javax.swing.JDialog,
       javax.swing.JFrame,
       javax.swing.JInternalFrame] do
    connect javax.swing.JMenuBar, :setJMenuBar  
  end

  type javax.swing.JMenu do
    connect javax.swing.Action, :add  
  end

  type javax.swing.JScrollPane do
    connect java.awt.Component, :setViewportView
    connect javax.swing.JViewport, :setViewport
    connect javax.swing.border.Border, :setViewportBorder
  end

  type javax.swing.JSplitPane do
    connect java.awt.Component do |pane,cmp,sym,props|
      unless pane.getLeftComponent
        pane.setLeftComponent(cmp)
      else
        warn 'too many components for JSplitPane, overwriting last' if pane.getRightComponent
        pane.setRightComponent(cmp)
      end
    end
  end

  type javax.swing.JTabbedPane do
    # TODO: background/foreground colors, mnemonic, selected
    # TODO: close button (:default or user JButton)
    connect java.awt.Component do |pane,cmp,sym,props|
      if props
        if Java6 && (tc = props[:tab])
          pane.addTab(S,cmp)
          i = pane.indexOfComponent(cmp)
          pane.setTabComponentAt(i,tc)
          # TODO: tooltip allowed for custom tab?
        else
          title = props[:title] || cmp.name || S
          icon = props[:icon]
          tooltip = props[:tooltip]
          pane.addTab(title,icon,cmp,tooltip)
        end
      else
        pane.addTab(cmp.name||S,cmp)
      end
    end  
  end
  
  type javax.swing.JTable do
    connect javax.swing.table.TableCellEditor, :setCellEditor
    connect javax.swing.table.TableColumn, :addColumn
  end

  type javax.swing.RootPaneContainer do
    connect java.awt.LayoutManager do |par,obj,*r|
      par.content_pane.layout = obj
    end
    connect javax.swing.border.Border do |par,obj,*r|
      par.content_pane.border = obj    
    end
  end
  
  type javax.swing.text.JTextComponent do
    connect javax.swing.border.Border, :setBorder
    connect java.lang.Object do |tc,obj,*r|
      tc.setText(obj.toString)
    end  
    connect Object do |tc,obj,*r|
      tc.setText(obj.to_s)    
    end
  end

  # TODO: more generic TreeNode insertion
  
  type javax.swing.tree.DefaultMutableTreeNode do
    connect javax.swing.tree.MutableTreeNode do |par,obj,sym,props|
      if Hash === props && (tree = props[:tree])
        tree.model.insert_node_into(obj,par,par.child_count)
        tree.scroll_path_to_visible(TreePath.new(obj.path)) if props[:visible]
      else
        par.add(obj)
      end
    end  
  end

  type org.cheri.swing.layout.GridTable do
    connect java.awt.Component do |table,comp,sym,constraints|
      if constraints && !constraints.empty?
        if gbc = constraints[:constraints] && GridBagConstraints === gbc
          table.add(comp,gbc)
        else
          table.add(comp,constraints)
        end
      else
        #table.add(comp)
        # workaround intermittent JRuby bug with overloaded methods
        table.add(comp,nil)      
      end
    end
    connect org.cheri.swing.layout.GridRow do |table,row,sym,constraints|
      #row.default_constraints = constraints if constraints && !constraints.empty?
      table.add_row row, constraints
    end
  end

  type org.cheri.swing.layout.GridRow do
    connect java.awt.Component do |row,comp,sym,constraints|
      if constraints && !constraints.empty?
        row.add(comp,constraints)
      else
        #row.add(comp)
        # workaround intermittent JRuby bug with overloaded methods
        row.add(comp, nil)
      end
    end
  end

  type java.awt.Container do
    connect org.cheri.swing.layout.GridRow do |cnt,row,sym,constraints|
      if GridTableLayout === (gtl = cnt.get_layout)
        gtl.add_row row, constraints
      else
        warn "grid_row specified but layout is not GridTableLayout"
      end
    end
  end
  
  type javax.swing.RootPaneContainer do
    connect org.cheri.swing.layout.GridRow do |cnt,row,sym,constraints|
      if GridTableLayout === (gtl = cnt.content_pane.get_layout)
        gtl.add_row row, constraints
      else
        warn "grid_row specified but layout is not GridTableLayout"
      end
    end
  end


end #SwingConnecter

end #Swing
end #Cheri
