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
module AWT
module Types
CJava = Cheri::Java
JA = 'java.awt.'.freeze
class << self
  def get_class(y)
    # TODO: threadsafe support? Probably not necessary if we're not adding keys.
    c = @classes[y]
    if c
      if c.instance_of?(String)
        c = CJava.get_class(JA + c)
        @classes[y] = c if c
      end
      c
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
  :alpha_composite => 'AlphaComposite',
  :awt_event => 'AWTEvent',
  :awt_event_multicaster => 'AWTEventMulticaster',
  :awt_key_stroke => 'AWTKeyStroke',
  :awt_permission => 'AWTPermission',
  :basic_stroke => 'BasicStroke',
  :border_layout => 'BorderLayout',
  :buffer_capabilities => 'BufferCapabilities',
  :buffer_capabilities_flip_contents => 'BufferCapabilities::FlipContents',
  :button => 'Button',
  :canvas => 'Canvas',
  :card_layout => 'CardLayout',
  :checkbox => 'Checkbox',
  :checkbox_group => 'CheckboxGroup',
  :checkbox_menu_item => 'CheckboxMenuItem',
  :choice => 'Choice',
  :color => 'Color',
  :component => 'Component',
  :component_orientation => 'ComponentOrientation',
  :container => 'Container',
  :container_order_focus_traversal_policy => 'ContainerOrderFocusTraversalPolicy',
  :cursor => 'Cursor',
  :default_focus_traversal_policy => 'DefaultFocusTraversalPolicy',
  :default_keyboard_focus_manager => 'DefaultKeyboardFocusManager',
  :desktop => 'Desktop',
  :dialog => 'Dialog',
  :dimension => 'Dimension',
  :display_mode => 'DisplayMode',
  :event => 'Event',
  :event_queue => 'EventQueue',
  :file_dialog => 'FileDialog',
  :flow_layout => 'FlowLayout',
  :focus_traversal_policy => 'FocusTraversalPolicy',
  :font => 'Font',
  :font_metrics => 'FontMetrics',
  :frame => 'Frame',
  :gradient_paint => 'GradientPaint',
  :graphics => 'Graphics',
  :graphics_2d => 'Graphics2D',
  :graphics_config_template => 'GraphicsConfigTemplate',
  :graphics_configuration => 'GraphicsConfiguration',
  :graphics_device => 'GraphicsDevice',
  :graphics_environment => 'GraphicsEnvironment',
  :grid_bag_constraints => 'GridBagConstraints',
  :grid_bag_layout => 'GridBagLayout',
  :grid_bag_layout_info => 'GridBagLayoutInfo',
  :grid_layout => 'GridLayout',
  :image => 'Image',
  :image_capabilities => 'ImageCapabilities',
  :insets => 'Insets',
  :job_attributes => 'JobAttributes',
  :keyboard_focus_manager => 'KeyboardFocusManager',
  :label => 'Label',
  :linear_gradient_paint => 'LinearGradientPaint',
  :list => 'List',
  :media_tracker => 'MediaTracker',
  :menu => 'Menu',
  :menu_bar => 'MenuBar',
  :menu_component => 'MenuComponent',
  :menu_item => 'MenuItem',
  :menu_shortcut => 'MenuShortcut',
  :mouse_info => 'MouseInfo',
  :multiple_gradient_paint => 'MultipleGradientPaint',
  :page_attributes => 'PageAttributes',
  :panel => 'Panel',
  :point => 'Point',
  :pointer_info => 'PointerInfo',
  :polygon => 'Polygon',
  :popup_menu => 'PopupMenu',
  :print_job => 'PrintJob',
  :radial_gradient_paint => 'RadialGradientPaint',
  :rectangle => 'Rectangle',
  :rendering_hints => 'RenderingHints',
  :rendering_hints_key => 'RenderingHints::Key',
  :robot => 'Robot',
  :scrollbar => 'Scrollbar',
  :scroll_pane => 'ScrollPane',
  :scroll_pane_adjustable => 'ScrollPaneAdjustable',
  :splash_screen => 'SplashScreen',
  :system_color => 'SystemColor',
  :system_tray => 'SystemTray',
  :text_area => 'TextArea',
  :text_component => 'TextComponent',
  :text_field => 'TextField',
  :texture_paint => 'TexturePaint',
  :toolkit => 'Toolkit',
  :tray_icon => 'TrayIcon',
  :window => 'Window',
  :clipboard => 'datatransfer.Clipboard',
  :data_flavor => 'datatransfer.DataFlavor',
  :flavor_event => 'datatransfer.FlavorEvent',
  :string_selection => 'datatransfer.StringSelection',
  :affine_transform => 'geom.AffineTransform',
  :arc_2d_double => 'geom.Arc2D::Double',
  :arc_2d_float => 'geom.Arc2D::Float',
  :area => 'geom.Area ',
  :cubic_curve_2d_double => 'geom.CubicCurve2D::Double',
  :cubic_curve_2d_float => 'geom.CubicCurve2D::Float',
  :ellipse_2d_double => 'geom.Ellipse2D::Double',
  :ellipse_2d_float => 'geom.Ellipse2D::Float',
  :flattening_path_iterator => 'geom.FlatteningPathIterator',
  :general_path => 'geom.GeneralPath',
  :line_2d_double => 'geom.Line2D::Double',
  :line_2d_float => 'geom.Line2D::Float',
  :path_2d_double => 'geom.Path2D::Double',
  :path_2d_float => 'geom.Path2D::Float',
  :point_2d_double => 'geom.Point2D::Double',
  :point_2d_float => 'geom.Point2D::Float',
  :quad_curve_2d_double => 'geom.QuadCurve2D::Double',
  :quad_curve_2d_float => 'geom.QuadCurve2D::Float',
  :rectangle_2d_double => 'geom.Rectangle2D::Double',
  :rectangle_2d_float => 'geom.Rectangle2D::Float',
  :round_rectangle_2d_double => 'geom.RoundRectangle2D::Double',
  :round_rectangle_2d_float => 'geom.RoundRectangle2D::Float',
  :affine_transform_op => 'image.AffineTransformOp',
  :area_averaging_scale_filter => 'image.AreaAveragingScaleFilter',
  :band_combine_op => 'image.BandCombineOp',
  :banded_sample_model => 'image.BandedSampleModel',
  :buffered_image => 'image.BufferedImage',
  :buffered_image_filter => 'image.BufferedImageFilter',
  :buffer_strategy => 'image.BufferStrategy',
  :byte_lookup_table => 'image.ByteLookupTable',
  :color_convert_op => 'image.ColorConvertOp',
  :color_model => 'image.ColorModel',
  :component_color_model => 'image.ComponentColorModel',
  :component_sample_model => 'image.ComponentSampleModel',
  :convolve_op => 'image.ConvolveOp',
  :crop_image_filter => 'image.CropImageFilter',
  :data_buffer => 'image.DataBuffer',
  :data_buffer_byte => 'image.DataBufferByte',
  :data_buffer_double => 'image.DataBufferDouble',
  :data_buffer_float => 'image.DataBufferFloat',
  :data_buffer_int => 'image.DataBufferInt',
  :data_buffer_short => 'image.DataBufferShort',
  :data_buffer_ushort => 'image.DataBufferUShort',
  :direct_color_model => 'image.DirectColorModel',
  :filtered_image_source => 'image.FilteredImageSource',
  :image_filter => 'image.ImageFilter',
  :index_color_model => 'image.IndexColorModel',
  :kernel => 'image.Kernel',
  :lookup_op => 'image.LookupOp',
  :lookup_table => 'image.LookupTable',
  :memory_image_source => 'image.MemoryImageSource',
  :multi_pixel_packed_sample_model => 'image.MultiPixelPackedSampleModel',
  :packed_color_model => 'image.PackedColorModel',
  :pixel_grabber => 'image.PixelGrabber',
  :pixel_interleaved_sample_model => 'image.PixelInterleavedSampleModel',
  :raster => 'image.Raster',
  :replicate_scale_filter => 'image.ReplicateScaleFilter',
  :rescale_op => 'image.RescaleOp',
  :rgb_image_filter => 'image.RGBImageFilter',
  :rgb_image_filter => 'image.RGBImageFilter',
  :sample_model => 'image.SampleModel',
  :short_lookup_table => 'image.ShortLookupTable',
  :single_pixel_packed_sample_model => 'image.SinglePixelPackedSampleModel',
  :volatile_image => 'image.VolatileImage ',
  :writable_raster => 'image.WritableRaster',
  :parameter_block => 'image.renderable.ParameterBlock',
  :renderable_image_op => 'image.renderable.RenderableImageOp',
  :renderable_image_producer => 'image.renderable.RenderableImageProducer',
  :render_context => 'image.renderable.RenderContext',
}  

end #Types
end #AWT
end #Cheri

#cls = Cheri::AWT::Types.get_class(:frame)
#puts cls.java_class.name
