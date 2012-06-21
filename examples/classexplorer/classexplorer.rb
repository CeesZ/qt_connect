# encoding: utf-8
$KCODE = 'UTF8' if RUBY_VERSION =~ /1\.8/
=begin

    Author:     Cees Zeelenberg (c.zeelenberg@computer.org)
    Copyright:  (c) 2011-2012 by Cees Zeelenberg
    License:    This program is free software; you can redistribute it and/or modify  
                it under the terms of the GNU Lesser General Public License as published
                by the Free Software Foundation; either version 2 of the License, or 
                (at your option) any later version.                       *
=end

unless RUBY_PLATFORM =~ /java/
  puts "Sorry!"
  puts "Class Explorer is an application"
  puts "for browsing Qt Jambi class definitions"
  puts "it can only be run using JRuby"
  exit
end

require 'qt_connect'
require 'qt_extensions'
require 'menus'
require 'packagetree'

class ClassExplorer < Qt::MainWindow
  
  MARKERS=[
    [:"final?", 'Final Java method', '#81F7F3'],
    [:"abstract?", 'Abstract Java method', '#F5D0A9'],
    [:"ruby?", 'Ruby method', 'yellow']]
    
  BGCOLOR="#ccccff"
  
  def initialize

    super
    setup_UI
    setup_panels
    setup_menu_bar
    create_dock_window
    read_settings
    @java_root_edit.text=@root
    @java_root_edit.textChanged.connect{ |s| @root=s }
    @java_root_edit.editing_finished.connect{ show_class(@lastpath) if @lastpath}
    @packagetree=PackageTree.new('com.trolltech.qt')
    @package_list.model=PackageModel.new(@packagetree)
    @package_list.clicked.connect( self,:on_package_clicked)
    @package_list.selectionModel=Qt::ItemSelectionModel.new(@package_list.model)
    #use stylesheet to set selection-background-color
    #default background color is wrong if item selected but not in focus
    @package_list.styleSheet=%Q[selection-background-color: #3399ff; selection-color: white;]
    
    @class_list.model=FilteredClassModel.new(@filter_line_edit)
    @class_list.clicked.connect(self,:on_class_clicked)
    @class_list.selectionModel=Qt::ItemSelectionModel.new(@class_list.model)
    @class_list.styleSheet=%Q[selection-background-color: #3399ff; selection-color: white;]
    
    MethodAttributes.namespace{ |method| rubyname(method) }

    Qt::Internal::RUBY_extensions.each{ |method|
      mas=MethodAttributes.new(method)
      mas.lang=:ruby
      @newmethods[mas.receiver] ||=[]
      @newmethods[mas.receiver] << mas
    }
    #initial selection: all packages
    @package_list.select_all
    update_class_panel
	on_package_clicked(0)

  end
    
  def setup_UI
    resize(1000,768)
    # the widgets composing the UI
    @central_widget=Qt::Widget.new
    @caption=Qt::Label.new('')
    @package_list=Qt::ListView.new
    @class_list=Qt::ListView.new
    @detail_panel=Qt::TextBrowser.new
    @nav_left=Qt::ToolButton.new{ |tb| tb.icon=style.standardIcon(Qt::Style::SP_ArrowLeft)}
    @nav_right=Qt::ToolButton.new{ |tb| tb.icon=style.standardIcon(Qt::Style::SP_ArrowRight)}
    @inherit_box=Qt::CheckBox.new('include inherited Qt members')    
    @linkto_box=Qt::CheckBox.new('link to Qt Jambi Reference Documentation')
    @filter_line_edit=QtExtensions::LineEdit.new

    #the layout for the widgets
    options_layout=Qt::VBoxLayout.new{ |v|
      v.add_widget(@inherit_box,0)
      v.add_widget(@linkto_box,0)
      v.add_stretch(100)
    }
  
   navigate_layout=Qt::HBoxLayout.new{ |h|
      h.add_widget(@nav_left,0)
      h.add_widget(@nav_right,0)
      h.add_stretch(100)
    }
  
    header_layout=Qt::VBoxLayout.new{ |v|
      v.add_layout(navigate_layout,0)
      v.add_widget(@caption,99)
    }
        
    
    footer=Qt::Label.new(html_footer)

    headerframe_layout=Qt::HBoxLayout.new{ |h|
      h.add_layout(header_layout,99)
      h.add_layout(options_layout,0)
   
   }
    
    leftframe=Qt::Widget.new { |f|
      #f.frame_style=Qt::Frame::Panel | Qt::Frame::Plain
      f.layout=Qt::VBoxLayout.new { |v|
        v.add_widget(@package_list,30)
        v.add_widget(@class_list,70)
        v.add_widget(@filter_line_edit,0)
      }
    }
    
    rightframe=Qt::Widget.new { |f|
      #f.frame_style=Qt::Frame::Panel | Qt::Frame::Plain
      f.layout=Qt::VBoxLayout.new { |v|
        v.add_layout(headerframe_layout,0)
        v.add_widget(@detail_panel,99)
        v.add_widget(footer,0)
      }
    }
    #use a splitter as a flexible divider between left and right frames
    @splitter=splitter=Qt::Splitter.new(Qt::Horizontal){ |s|
      s.add_widget(leftframe)
      s.add_widget(rightframe)
    }
    @splitter.sizes=[200,800]
    
    @central_widget.layout=Qt::VBoxLayout.new { |v|
      v.add_widget(@splitter,100)
    }
    self.central_widget=@central_widget
  end
  def setup_panels
    @package_list.view_mode=Qt::ListView::ListMode
    @package_list.selection_mode=Qt::ListView::SelectionMode::ExtendedSelection
    @package_list.selectionRectVisible=true
    @class_list.itemDelegate=QtExtensions::HtmlDelegate.new
    @inherit_box.state_changed.connect(self,:html_class_description)
    @linkto_box.toggled.connect{ |tf|
      next unless @dock
      @dock.visible=tf unless @dock.visible==tf
      show_class(@lastpath) if @lastpath && @dock.visible?
    }
    @newmethods={}
    @detail_panel.openLinks=false
    @detail_panel.anchorClicked.connect(self,:on_class_navigate)
    @filter_line_edit.placeholderText="Filter"
    @filter_line_edit.setClearButton
    @navigate=Navigator.new
    @navigate.browse{ |path| show_class(path)}
    @navigate.buttons(@nav_left,@nav_right)
  end
  
  def setup_menu_bar
    @menubar=Qt::MenuBar.new(self) { |menubar|
      setMenuBar(menubar)
      @helpmenu=Menus::HelpMenu.new(self,menubar)
    }
  end
  
  def create_dock_window
    java_label=Qt::Label.new('Javadoc root:')
    @java_root_edit=Qt::LineEdit.new
    @java_url_edit=Qt::LineEdit.new
    
    @jambibrowser=Qt::WebView.new
    @jambibrowser.html=''
    javadoc_header=Qt::Widget.new{ |w|
      w.layout=Qt::HBoxLayout.new { |h|
        h.add_widget(java_label,0)
        h.add_widget(@java_root_edit,99)
      }
    }
    @javadoc=Qt::Widget.new{ |w|
      w.layout=Qt::VBoxLayout.new{ |v|
        v.add_widget(javadoc_header,0)
        v.add_widget(@java_url_edit,0)
        v.add_widget(@jambibrowser,99)
      }
    }
    @dock = Qt::DockWidget.new("Qt Jambi Reference Documentation", self)
    @dock.objectName="Record_Browser"
    @dock.minimum_width=500
    @dock.allowedAreas = Qt::LeftDockWidgetArea | Qt::RightDockWidgetArea

    @dock.widget = @javadoc
    addDockWidget(Qt::RightDockWidgetArea, @dock)
    @dock.visibilityChanged.connect{ |tf|  @linkto_box.checked=tf unless @linkto_box.checked==tf}
  end

  def read_settings
    settings = Qt::Settings.new("Qt_connect", "Class Explorer")
	    pos = settings.value("pos", Qt::Point.new(200, 200))
	    size = settings.value("size", Qt::Size.new(1000,768))
      @linkto_box.checked=Qt::Variant.toBoolean(settings.value('linkto_box')) || false
      @inherit_box.checked=Qt::Variant.toBoolean(settings.value('inherit_box')) || false
      sz=Qt::Variant.toList(settings.value("splitter"))
	  @splitter.sizes= (sz.size==2) ? sz : [300,700]
      @root=Qt::Variant.toString(settings.value("root")) || "http://doc.trolltech.com/qtjambi-4.4/html"
      state=settings.value("state")
	    resize(size)
	    move(pos)
      restoreState(state) if state
  end
  
  #overrule (N.B. must use camelcase here!)
  def closeEvent(event)
    settings = Qt::Settings.new("Qt_connect", "Class Explorer")
    settings.setValue("pos",pos)
    settings.setValue("size",size)
    settings.setValue("state",saveState)
    settings.setValue("linkto_box",@linkto_box.checked?)
    settings.setValue("inherit_box",@inherit_box.checked?)
    settings.setValue("splitter",@splitter.sizes)
    settings.setValue("root",@root)
    super(event)
  end
  
  def on_package_clicked(index)
    update_class_panel
    ix0=@class_list.model.index(0,0)
    @class_list.selectionModel.select(ix0,Qt::ItemSelectionModel::SelectionFlag::ClearAndSelect)
    on_class_clicked(ix0)
  end
  def update_class_panel
    classes=@package_list.selectedIndexes.
      inject([]){ |memo,ix| memo += @package_list.model.classes(ix).
      map{ |c| rubyname(@package_list.model.data(ix) + '.' +c)}}.
      sort
    @class_list.clear_selection
    @class_list.model.layout_about_to_be_changed.emit
    @class_list.model.classes=classes
    @class_list.model.layout_changed.emit
    @filter_line_edit.text=''
  end

  def on_class_clicked(index)
    begin
      @rubyname=@class_list.model.data(index,Qt::UserRole)
      @klass=eval(@rubyname)
      @klass=qt_hierarchy(@klass)[-1]
      @path=@klass.java_class.name
    rescue => e
      puts "error on_class_clicked: #{e}"
      puts caller
      return
    end
    path=@path.gsub('.','/').gsub('$','.')
    navigate_to_class(path)
  end

  #url:   (QUrl) com/trolltech/qt/core/Qt.AlignmentFlag      => path: "com/trolltech/qt/gui/Qt.AlignmentFlag"
  #url:   (QUrl) com/trolltech/qt/gui/QAccessibleInterface  => path: "com/trolltech/qt/gui/QAccessibleInterface"
  #url:   (QUrl) com/trolltech/qt/gui/QAccessible.Method     => path: "com/trolltech/qt/gui/QAccessible.Method"
  def on_class_navigate(url)
    path=url.path
    @klass=eval(path.gsub('.','::').gsub('/','.')) rescue return
    @rubyname=rubyname(@klass)
    @path=@klass.java_class.name
    
    model=@package_list.model
    elems=@path.split('.')
    klass_name=elems.pop
    package_name=elems.join('.')
    return unless ix=(0...model.rowCount(0)).map{ |r| model.index(r,0)}.detect{ |m| model.data(m)==package_name}
    #if package present, but NOT selected in package_panel; select it now and update class_panel
    unless @package_list.selectedIndexes.detect{ |m| m==ix}
      @package_list.selectionModel.select(ix,Qt::ItemSelectionModel::SelectionFlag::Select)
      update_class_panel
    end
    
    @filter_line_edit.text=''
    model=@class_list.model
    return unless ix=(0...model.rowCount(0)).map{ |r| model.index(r,0)}.detect{ |m| model.data(m)==@rubyname}
    @class_list.selectionModel.select(ix,Qt::ItemSelectionModel::SelectionFlag::ClearAndSelect)
    @class_list.scrollTo(ix)
    on_class_clicked(ix)
    #navigate_to_class(path)
  end

  def navigate_to_class(path)
    @navigate.push(path)
    show_class(path)
  end
  
  def show_class(path)
    @klass=eval(path.gsub('.','::').gsub('/','.')) rescue return
    @rubyname=rubyname(@klass)
    @path=@klass.java_class.name
    @lastpath=path
    @caption.text=html_header
    html_class_description
    url=Qt::Url.new(%Q[#{@root}/]+path+".html")
    return unless @linkto_box.checked?
    begin
      @jambibrowser.load(url)
      @java_url_edit.text=url.toString
    rescue => e
      puts "error on_textbrowser: #{e}"
      print e.backtrace.join("\n")
    end
  end
  
  #
  #klass.class:
  #Module, Class: return name in Ruby namespace notation (e.g Qt::Widget, Qt::AbstractItemView::ConcreteWrapper)
  #String: convert all class references in string to Ruby namespace notation:
  #   com.trolltech.qt.gui.QAbstractItemView$ConcreteWrapper =>  Qt::AbstractItemView::ConcreteWrapper
  def rubyname(klass)
    if klass.respond_to?(:java_class)
      qtname=klass.java_class.name
    elsif klass.kind_of? String
      qtname="#{klass}"
    else                                          #Ruby defined class
      return klass.name
    end
    #remove longest matchingpackage (e.g. 'com.trolltech.qt.gui.QAbstractButton' =>  'Qt:AbstractButton')
    @packagetree.keys.sort{ |a,b| b.size <=> a.size}.
      each{ |package_name| qtname.gsub!(package_name + '.','Qt::')}
    
    qtname=qtname.gsub('$','::').
        gsub('Qt::Qt','Qt::').
        gsub('Qt::Q','Qt::').
        gsub('Qt::::','Qt::')
    qtname=qtname[0..-3] if qtname.end_with?('::')
    return qtname
  end

  def html_header
    %Q[<h2>
    <font size="-1">#{@packagetree.jars}
    <br>
    #{@path}</font>
    <br>
    #{@klass.class} #{@rubyname}</h2>]
  end

  def html_footer
    html='<table border="1" width="100%" cellpadding="3" cellspacing="0"><tr>'
    MARKERS.each{ |test,name,color| html+="<th bgcolor='#{color}'>#{name}</th>"}
    html+='</tr></table>'
    return html
  end

  #delete 'constants' from class_methods (static fields which implement constants)
  def html_class_description
    return unless @klass
    sort_methods
    @detail_panel.html= %Q[
  #{html_ancestors}
  <table border="1" width="100%" cellpadding="3" cellspacing="0" summary="">
  #{html_enums}
  #{html_constants}
  #{html_nested_classes}
  #{html_methods(@class_methods.delete_if{ |mas| @constants.include?(mas.methodname)},"#{@klass.class} Methods")}
  #{html_signals}
  #{html_methods(@instance_methods,"Instance Methods")}
  </table>
  ]
  end

  #Escape XML special characters <, & and >
  def escape(str)
    str.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
  end

  def qt_ancestors(klass)
    #klass.ancestors.delete_if{ |x| (!x.name.start_with? "Java::ComTrolltechQt")}
    return [] unless klass.respond_to? :ancestors
    klass.ancestors.select{ |x| x.name.start_with? "Java::ComTrolltechQt"}
  end

  def qt_hierarchy(klass)
    qt_ancestors(klass).
      map{ |ancestor| [ancestor,qt_ancestors(ancestor).size]}.
      sort{|a,b| a[1]<=>b[1]}.
      map{ |a,s| a}
  end

  def html_ancestors
    html=%Q[<table border="0"  cellpadding="4" cellspacing="0"><tr>]
    modules,classes=qt_hierarchy(@klass).
      partition{ |a| a.class==Module}.
      map{ |klasses|
        spaces=''
        inherit=' '
        klasses.map{ |x| leader=spaces+inherit ; spaces+=' '; inherit='┖' ; leader + html_qt_marker(rubyname(x))}.
        join("\n")
      }
    
    if modules.size==0  
      return html + "<th>Class Hierarchy</th><td><pre>#{classes}</pre></td></tr></table>"
    elsif classes.size==0
      return html + "<th>Module Hierarchy</th><td><pre>#{modules}</pre></td></tr></table>"
    else
      return html + %Q[<th>Class Hierarchy:</th><td><pre>#{classes}</pre></td>
            <th>Mixes in:</th>
            <td><pre>#{modules}</pre></td>
        </tr>
      </table>]
    end
   end
   
  def html_constants
  
    html=@constants.
      map{ |c| v=@klass.const_get(c)
        val="#{v}"
        name=(v.respond_to?(:java_class)) ? v.java_class.name : v.class.name
        if v.respond_to?(:value)
          val=" 0x%08x" % v.value
        elsif v.kind_of?(String)
          val='"' + v + '"'
        end
        [c.to_s,val,name]}.
      sort{ |a,b| (a[2]+a[0]) <=> (b[2]+b[0])}.
      uniq.
      delete_if{|xx| xx[0].start_with?('_')}.
      map{ |xx| "<tr><td>#{rubyname(xx[2])}</td><td>#{xx[0]}</td><td>#{xx[1]}</td></tr>"}
    return (html.size>0) ? %Q[
      <!-- =========================== Class Constants =========================== -->
      <tr bgcolor="#{BGCOLOR}">
      <th align="left" colspan="3"><font size="+2">
      <b>Constants</b></font></th>
      </tr>
      <font size='-1'><tr><th>class</th><th>object</th><th>value</th></tr></font>
      #{html}
      ] : ''
  end
    
  def html_enums
    html=''
    @constants=[]
    @enums=[]
    @ignore=[]
    @nested_classes=[]
    konstants=@klass.constants
    konstants.each{ |c|
      ancestors=(eval("#{@klass.name}::#{c}.respond_to? :ancestors")) ? eval("#{@klass.name}::#{c}.ancestors"): []
      if ancestors.include? java.lang.Enum
        @enums << c
      elsif (v=@klass.const_get(c)) && (v.class==Class)
        @nested_classes << c
      else
        @constants << c
      end
    }
    
    @enums.sort.each{ |enum|
      values=eval(%Q[#{@klass.name}::#{enum}.values]).to_ary
      enumname=html_qt_marker("#{@rubyname}::#{enum}")
      html += "<tr><td rowspan='#{values.size}'>#{enumname}</td>"
      tr=''
      values.each{ |v| 
        s="#{v}"
        fullname="#{@rubyname}::#{enum}::#{v}"
        shortname="#{@rubyname}::#{v}"
        name = if (Qt::Internal::DONT_ABBREVIATE[fullname]) || (s=~/\A[^A-Z].*\Z/)
          #!const_defined?(shortname.to_sym)
            "<font color='red'>#{fullname}</font>"
          else
            shortname
          end
        html+="#{tr}<td>#{v}</td><td>#{name}</td></tr>"
        tr="<tr>"
        @ignore << "#{v}"
      }
    }
    @constants -= @ignore

    return html unless html.size > 0
    return %Q[
    <!-- =========================== Class Enums =========================== -->
    <tr bgcolor="#{BGCOLOR}">
    <th align="left" colspan="3"><font size="+2">
    <b>Enums</b></font></th>
    </tr>
    <font size='-1'><tr><th>enumerator</th><th>values</th><th>shorthand</th></tr>#{html}</font>
    ]
  end

  def html_nested_classes
    html=@nested_classes.
      map{ |c| rubyname(@klass.const_get(c))}.
      delete_if{|name| name=='Qt::'}.
      delete_if{|name| !@inherit_box.is_checked? && !name.start_with?(@rubyname)}.
      sort.compact.
      map{ |name| html_qt_marker(name)}.
      join("\n")
    return (html.size>0) ? %Q[
    <!-- =========================== Nested Classes =========================== -->
    <tr bgcolor="#{BGCOLOR}">
    <th align="left" colspan="3"><font size="+2">
    <b>Nested classes</b></font></th>
    </tr>
    <tr></td><td colspan="3">#{html}</td></tr>
      ] : ''
  end

  def sort_methods
    @class_methods=[]
    @instance_methods=[]
    @fields=[]
    @signals={}
    rubynew=false
    if @klass.respond_to?(:java_class) && javaclass=@klass.java_class
      javamethods=org.jruby.javasupport.JavaClass.getMethods(javaclass).to_a
      qt_ancestors(@klass).each{ |klass|
        rname=rubyname(klass)
        javamethods+=(@newmethods[rname] || [])
      }
      javamethods.each{ |javamethod|
        mas=(javamethod.kind_of? MethodAttributes) ? javamethod : MethodAttributes.new(javamethod)
        next if mas.native?                                    #skip fromNativePointer etc.
        next if mas.methodname.start_with? "__qt"                 #in case not labeled 'native'
        next if !@inherit_box.is_checked? && (mas.receiver!=@rubyname)
        
        if mas.private?
          n=(mas.argtypes.size>0) ? mas.argtypes.count(',')+1 : 0
          @signals[mas.methodname+n.to_s]=(mas.argtypes.size==0) ? '()' : mas.argtypes
        elsif mas.static?
          @class_methods << mas
          rubynew=true if ((mas.methodname=='new') && (mas.lang==:ruby))
        else
          @instance_methods << mas
        end
      }
      org.jruby.javasupport.JavaClass.getFields(javaclass).each{ |javamethod|
        mas=MethodAttributes.new(javamethod)
        next if mas.methodname.start_with? "_"
        next if !@inherit_box.is_checked? && (mas.receiver!=@rubyname)
        if (mas.returntype=~ /SignalEmitter/)
          @fields << mas
        elsif mas.static?
          @class_methods << mas
        else
          @instance_methods << mas
        end
      }
      #ignore java constructors if 'new' class method was redefined (e.g. rubynew==true)
      if ((@klass.class==Class) && !rubynew) 
        javaclass.constructors.map{ |c|
          mas=MethodAttributes.new(c)
          mas.returntype=mas.methodname
          mas.methodname='new'
          mas.lang=:ruby
          @class_methods<<mas
        }
      end
        
    end
  end

  def html_methods(methods,caption)
    html=''
    methods.sort{ |a,b| a.methodname <=> b.methodname}.each{ |method|
      next if (receiver=method.receiver) && !receiver.start_with?('Qt::') #only show inheritance from Qt members
      bgcolor=''
      MARKERS.each{ |test,name,color| bgcolor=color if method.send(test)} 
      html+=%Q[<tr>]
      html+="<td>" + html_qt_marker(method.returntype) + "</td>"
      html+="<td bgcolor='#{bgcolor}'><b>" + escape(method.methodname) + "</b>"
      
      if (method.argtypes.size>0)
        html += '(' + method.argtypes[1..-2].split(',').map{ |arg| html_qt_marker(arg)}.join(', ') +')'
      end
      html+="</td>"
      #html+= method.annotations ? escape(" {#{method.annotations}}") : ''
      html+=(method.receiver==@rubyname) ? '<td></td>' : "<td>#{html_qt_marker(method.receiver||'')}</td>" if @inherit_box.is_checked?
      html+="</tr>"
    }
        return (html.size>0) ? %Q[
        <!-- =========================== Instance Methods =========================== -->
        <tr bgcolor="#{BGCOLOR}">
        <th align="left" colspan='#{@inherit_box.is_checked? ? '3' : '3'}'><font size="+2">
        <b>#{caption}</b></font></th>
        #{"<tr bgcolor='#ccccff'><th colspan='2'></th><th>Inherited from</th>" if @inherit_box.is_checked?}
        </tr>
        #{html}
        ] : ''
  end

  def html_qt_marker(s)
    html=escape(s)
    begin
      if s.start_with?('Qt::') && s!=@rubyname && s!=(@rubyname+'[]') &&
        (klass=eval(s.gsub('[]',''))) && (klass.respond_to? :java_class)
            url=klass.java_class.name.gsub('.','/').gsub('$','.')
            html="<a href='#{url}'>" + escape(s) + "</a>" 
      end
    rescue
    end

    return html
  end

  def html_signals
    html=''
      @fields.sort{ |a,b| a.methodname <=> b.methodname}.each{ |method|
        n=method.returntype[-1,1]
        #emitargs=escape(@signals[method.methodname+n] || '')
        emitargs= if (x=@signals[method.methodname+n]) && (x.size>0)
           '(' + x[1..-2].
              split(',').
              map{ |arg| html_qt_marker(arg)}.
              join(', ') +
            ')'
        else
          '()'
        end
        html+=%Q[<tr><td>#{html_qt_marker(method.returntype)}</td>
                     <td>#{escape(method.methodname)}</td
                     ><td bgcolor="yellow"><i>slot</i>#{emitargs}</td></tr>]
      }
      return (html.size>0) ? %Q[
        <!-- =========================== Signals =========================== -->
        <tr bgcolor="#{BGCOLOR}">
        <th align="left" colspan="3"><font size="+2">
        <b>Signals</b></font></th>
        </tr>
        <font size='-1'><tr><th colspan="2">signalemitter</th><th>connects to</th>
        #{html}
        ] : ''
  end
    
end


class MethodAttributes
  attr_accessor :returntype,:methodname,:receiver,:argtypes,:lang,:prefixes,:annotations
    #call with either signature string OR
    #Java::JavaLangReflect::Method OR
    #Java::JavaLangReflect::Field OR
    #Java::JavaConstructor
    def self.namespace(&block)
      @@block=block
    end
    
    def initialize(javamethod)
    #public final com.trolltech.qt.core.QPoint com.trolltech.qt.gui.QWidget.mapFrom(com.trolltech.qt.gui.QWidget,com.trolltech.qt.core.QPoint)
    #public final com.trolltech.qt.core.QSize com.trolltech.qt.gui.QAbstractButton.iconSize()
    #public final com.trolltech.qt.core.Qt$LayoutDirection com.trolltech.qt.gui.QWidget.layoutDirection()
    #public final void com.trolltech.qt.gui.QWidget.grabMouse(com.trolltech.qt.gui.QCursor)
    #protected void com.trolltech.qt.gui.QWidget.dragLeaveEvent(com.trolltech.qt.gui.QDragLeaveEvent)
    @annotations=nil
    if javamethod.respond_to?(:annotations)
      @annotations=javamethod.annotations.
        map{ |ann| ann.to_java(java.lang.annotation.Annotation).toString}.
        join(',').
        gsub!('@com.trolltech.qt.','')
    end
    method=@@block.call("#{javamethod}")
    elems=method.split('(')
    @prefixes=elems[0].split(' ')
    @returntype=@prefixes[-2]
    #@returntype=@prefixes[0..-2]
    @methodname=@prefixes[-1].split('.')[-1]
    @receiver=@prefixes[-1].split('.')[-2]
    @argtypes=(elems.size>1) ? (elems[1].split(')')[0] || '') : ''
    @argtypes='('+@argtypes+')' if @argtypes.size>0
    @lang=:java
  end
  def ruby?
    @lang==:ruby
  end
  #
  # .final, public, private, protected, abstract
  # .public?
  def method_missing(symbol,*args)
    m=symbol.to_s[0...-1]
    return @prefixes.include?(m)
  end
end

class PackageModel < Qt::AbstractListModel
  
  def initialize(packagetree)
    @package_tree=packagetree
    @packages=packagetree.keys & Qt::Internal::Packages
    super()
  end
  
  def classes(index)
    package_name=@packages[index.row]
    @package_tree[package_name].classes
  end
  

  def data(index, role=Qt::DisplayRole)
    return @packages[index.row] if role == Qt::DisplayRole
    return Qt::Variant.new
  end
  
  def rowCount(parent)
    return @packages.size
  end
  
end

#Qt::AbstractListModel specialized for acess to Classes
#supports active filter (respons while you type)
#filter_edit is Qt::LineEdit monitored for text changes, otherwise managed outside this class
#data supports Qt::UserRole (returns Class name as String)
# and Qt::DisplayRole (returns Class name as HTML with tagged filter matches)
class FilteredClassModel < Qt::AbstractListModel
  
  def initialize(filter_edit,max_cache=20)
    super()
    @filter_edit=filter_edit
    @max_cache=max_cache
    @classes=[]
    @row2rec=[]
    reset_filter
    @filter_edit.textChanged.connect{ |s| filter_changed(s)}
  end
  
  def classes=(cl)
    @classes=cl
    @row2rec=(0...@classes.size).to_a
    reset_filter
  end
  
  def data(index, role=Qt::DisplayRole)
    return Qt::Variant.new if index.row >= @row2rec.size
    return @classes[@row2rec[index.row]] if role == Qt::UserRole
    return Qt::Variant.new unless role == Qt::DisplayRole
    s=@classes[@row2rec[index.row]].gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    s=s.gsub(@rx){ |m| %Q[<span class="hilite">#{m}</span>]} if @filter.size>0
    return s
    
  end
  
  def rowCount(parent)
    return @row2rec.size
  end
  
  private
  
  def reset_filter
    @filter=''
    @history={}
    @cache={}
    @filter_edit.text=''
  end
  
  def filter_changed(str)
    s=str.downcase
    @rx=Regexp.new(Regexp.escape(s),Regexp::IGNORECASE)
    if s==''
      row2rec=(0...@classes.size).to_a
    elsif row2rec=@cache[s]
    elsif (s.size>1) && (s[0...-1]==@filter)
      row2rec=@row2rec.select{ |i| @classes[i] =~ @rx}
    else
      row2rec=(0...@classes.size).select{ |i| @classes[i] =~ @rx}
    end
    @filter=s
    layout_about_to_be_changed.emit
    @row2rec=row2rec
    layout_changed.emit
    @cache[s]=row2rec
    @history[s]=Time.now
    if @history.size > @max_cache
      s=@history.sort{ |a,b| a[1] <=> b[1]}.first.first
      @cache.delete(s)
      @history.delete(s)
    end
        
  end

end
# simple class to assist fwd/bwd navigation
# left/right are Qt widgets than can be enabled/disabled and clicked
#push: add a page to the end of the queue
#browse: passes a call-back block to display a page
class Navigator
  def initialize
    @browse=nil
    @left=nil
    @right=nil
    @index=0
    @history=[]
  end
  def buttons(left,right)
    @left=left
    @left.enabled=false
    @left.clicked.connect{move(-1)}
    @right=right
    @right.enabled=false
    @right.clicked.connect{move(1)}
  end
  
  def push(page)
    @history << page
    @index=-1
    @left.enabled=(@history.size>1)
    @right.enabled=false
  end
  
  def browse(&block)
    @browse=block
  end
  
  private
  
  def move(delta)
    return if (@index+delta >=0) || (@history.size+@index+delta<0)
    @index+=delta
    @browse.call(@history[@index]) if @browse
    @left.enabled=(@history.size+@index>0)
    @right.enabled=(@index<-1)
  end
end

  app=Qt::Application.new(ARGV)
  classexplorer=ClassExplorer.new
  classexplorer.show
  app.exec
 