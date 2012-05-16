=begin

    Author:     Cees Zeelenberg (c.zeelenberg@computer.org)
    Copyright:  (c) 2010-2012 by Cees Zeelenberg
    License:    This program is free software; you can redistribute it and/or modify  
                it under the terms of the GNU Lesser General Public License as published
                by the Free Software Foundation; either version 2 of the License, or 
                (at your option) any later version.                       *

    This software extends the basic qt_jbindings API with functionality to
    improve compatibility with the existing QtRuby API:
    - same shorthand notations for Enums
    - patches to classes where the API is slightly different to support
      both interfaces (ongoing work)
    - support for the QtRuby signals/slot interface in addition
      to the QtJambi signals interface
    - implementations of Qt::Variant and Qt::ModelIndex to allow single source
      maintenance for QtRuby and QtJRuby
    
    
=end
module Qt

module Internal

  # for all constants which inherit from the Enum class or are  "public static final int" fields
  # define a shorthand notation to be compatible with the Ruby version of qtbindings
  # e.g. Qt::PenStyle::SolidLine can be abbreviated to Qt::SolidLine
  #suppress clashing or otherwise undesirable shorthands with an entry in the DONT_ABBREVIATE hash.
  
    DONT_ABBREVIATE= { 
        'Qt::WindowType::Widget' => true,
        'Qt::WindowType::Dialog' => true,
        'Qt::WindowType::ToolTip' => true,
        'Qt::WindowType::SplashScreen' => true,
        
        'Qt::Style::PixelMetric::CustomEnum' => true,
        'Qt::Style::PrimitiveElement::CustomEnum' => true,
        'Qt::Style::ContentsType::CustomEnum' => true,
        'Qt::Style::ComplexControl::CustomEnum' => true,
        'Qt::Style::SubElement::CustomEnum' => true,
        'Qt::Style::ControlElement::CustomEnum' => true,
        'Qt::Style::StandardPixmap::CustomEnum' => true,
      }
  end
  
  # 'create_constants' is called whenever new Module or Class is activated
  #qtclass    Java::ComTrollTechQtGui::QDockWidget (Class)
  #qtname     Qt::Dockwidget (String)
  def self.create_constants(qtclass,qtname)
    qtclass.class_eval{
      constants.dup.each{ |c|
        embedded_class=eval("#{qtclass.name}::#{c}")
        next unless embedded_class.respond_to?(:java_class)
        ancestors=(embedded_class.respond_to?(:ancestors)) ? embedded_class.ancestors : []
        if ancestors.include? java.lang.Enum
          embedded_class.values.to_ary.each{ |s|
            symbol=s.toString
            next if Qt::Internal::DONT_ABBREVIATE["#{qtname}::#{c}::#{symbol}"]
            next if symbol=~/\A[^A-Z].*\Z/
            next if const_defined?(symbol)
            qtclass.class_eval("#{symbol}=#{qtclass.name}::#{c}::#{symbol}") rescue next
          }
        else
          #could be class with public static final int field(s)
          fields=embedded_class.java_class.fields rescue next
          fields.each{ |field|
            next unless field.static? && field.final? && field.public? && (field.value_type=="int")
            symbol=field.name
            value=Java.java_to_ruby(field.static_value)
            qtclass.class_eval("#{symbol}=#{value}") rescue next
          }
        end
      }
    }
  end
  
  create_constants(self,'Qt')
  
  #compat QtRuby4 (fails for WindowType)
  WidgetType=WindowType::Widget
  #WindowType=WindowType::Window
  DialogType=WindowType::Dialog
  SheetType=WindowType::Sheet
  DrawerType=WindowType::Drawer
  PopupType=WindowType::Popup
  ToolType=WindowType::Tool
  ToolTipType=WindowType::ToolTip
  SplashScreenType=WindowType::SplashScreen
  DesktopType=WindowType::Desktop
 SubWindowType=WindowType::SubWindow
  
  #deal with Qt::blue etc.
  def Qt.method_missing(method,*args)
    return Color.send(method) if Color.respond_to?(method)
    return Color.new(*args).rgba if method==:qRgba
    super(*args)
  end
  
  class MetaObject < QtJambi::QObject
    def self.connectSlotsByName(arg)
      arg.connectSlotsByName()
    end
  end
  
  #mutable boolean for compatibility compatibility with qtruby
  #
  class Boolean
    attr_accessor :value
    def initialize(b=false) @value = b end
    def nil? 
      return !@value 
    end
  end
  

  class ModelIndex
    class <<self
      def new
        return nil
      end
    end
  end
  
  #
  #following are patches to QtJambi classes, mostly for compatibility with qtruby
  #Corresponding Procs are 'class_eval-ed' when a Qt class is activated
  #see companion code: qt_jbindings  Qt#const_missing
  # 'signature' calls are for documentation only (e.g. classexplorer.rb) and have
  # no effect on the functionality  
  module Internal
    
    signature "void Qt::AbstractSlider.range=(Range)"
    AbstractSlider=Proc.new do
          def range=(arg)
            if arg.kind_of? Range
              return setRange(arg.begin, arg.exclude_end?  ? arg.end - 1 : arg.end)
            else
              return setRange(arg)
            end
          end
    end

    
    #QtRuby uses: Qt::AbstractTextDocumentLayout::PaintContext.new
    #QtJambi : Qt::AbstractTextDocumentLayout_PaintContext
    AbstractTextDocumentLayout=Proc.new do
          self.const_set('PaintContext',Qt::AbstractTextDocumentLayout_PaintContext)
    end

    #example\dialogs\simplewizard
    signature "Qt::ByteArray Qt::ByteArray.+(Object)"
    ByteArray=Proc.new do
      def +(o)
        self.clone.append(o)
      end
    end
    
    signature "static Qt::DataStream Qt::DataStream.new"
    signature "static Qt::DataStream Qt::DataStream.new(Qt::IODevice)"
    signature "static Qt::DataStream Qt::DataStream.new(Qt::ByteArray)"
    signature "static Qt::DataStream Qt::DataStream.new(Qt::ByteArray, Qt::IODevice::OpenMode)"
    signature "static Qt::DataStream Qt::DataStream.new(Qt::ByteArray, int openmode)"
    signature "static Qt::DataStream Qt::DataStream.new(Qt::ByteArray, Qt::IODevice::OpenModeFlag[])"
    signature "void Qt::DataStream.setVersion(Enum)"
    signature "Qt::DataStream Qt::DataStream.<<(Object)"
    signature "Qt::DataStream Qt::DataStream.>>(Object)"
        DataStream=Proc.new do
          class << self
            alias :orig_new :new
            def new(*a,&block)
              args=a.dup
              args[1]=Qt::IODevice::OpenMode.new(args[1]) if (args.size>1) && args[1].kind_of?(Fixnum)
              return orig_new(*args,&block)
            end
          end
          alias orig_setVersion setVersion
          def setVersion(a)
            orig_setVersion(a.respond_to?(:value) ? a.value : a)
          end
          alias set_version setVersion
          alias version= setVersion
          def <<(arg)
            case arg
              when String ; writeString(arg)
              when Float,Java::Float ; writeFloat(arg)
              when Fixnum,Java::Int ; writeInt(arg)
              when Java::Double ; writeDouble(arg)
              when Java::ComTrolltechQtGui::QPixmap,
                    Java::ComTrolltechQtGui::QImage,
                    Java::ComTrolltechQtCore::QPointF,
                    Java::ComTrolltechQtCore::QPoint,
                    Java::ComTrolltechQtCore::QRect,
                    Java::ComTrolltechQtCore::QRectF,
                    Java::ComTrolltechQtGui::QRegion,
                    Java::ComTrolltechQtCore::QSize,
                    Java::ComTrolltechQtCore::QSizeF
                  arg.writeTo(self)
              else 
                raise "Qt::Datastream: no '<<' for #{arg.class}"
            end
            self # allows concatenation
          end
          def >>(arg)
            case arg
              when String ; arg=readString
              when Float ; arg=readFloat
              when Fixnum ; arg=readInt
              when Java::ComTrolltechQtGui::QPixmap,
                    Java::ComTrolltechQtGui::QImage,
                    Java::ComTrolltechQtCore::QPointF,
                    Java::ComTrolltechQtCore::QPoint,
                    Java::ComTrolltechQtCore::QRect,
                    Java::ComTrolltechQtCore::QRectF,
                    Java::ComTrolltechQtGui::QRegion,
                    Java::ComTrolltechQtCore::QSize,
                    Java::ComTrolltechQtCore::QSizeF
              arg.readFrom(self)
            else
              raise "Qt::Datastream: no '>>' for #{arg.class}"
            end
            self
          end
        end
    signature "void Qt::DoubleSpinBox.range=(Range)"
        DoubleSpinBox=Proc.new do
          def range=(arg)
            if arg.kind_of? Range
              return setRange(arg.begin, arg.exclude_end?  ? arg.end - 1 : arg.end)
            else
              return setRange(arg)
            end
          end
        end
    #examples\draganddrop\draggabletext
    signature "Qt::DropAction Qt::Drag.start"
    signature "Qt::DropAction Qt::Drag.start(Fixnum dropactions)"
    signature "Qt::DropAction Qt::Drag.start(Qt::DropAction[])"
    signature "Qt::DropAction Qt::Drag.start(Qt::DropActions)"
    signature "Qt::DropAction Qt::Drag.start(Qt::DropActions,Qt::DropAction)"
        Drag=Proc.new do
          alias orig_exec exec
            def exec(*a)
              args=a.dup
              args[0]=Qt::DropActions.new(args[0]) if args[0].kind_of? Fixnum
              orig_exec(*args)
            end
            alias :start :exec
        end    
    #example\dialogs\findfile
    signature "boolean Qt::File.open(Fixnum openmode)"
    File=Proc.new do
      alias orig_open open
      def open(a)
        arg=(a.kind_of?(Fixnum)) ? Qt::IODevice::OpenMode.new(a) : a
        orig_open(arg)
      end
    end
    
    signature "static java.lang.String Qt::FileDialog.getSaveFileName(Qt::Widget,String,String,String filter)"
    signature "static java.lang.String Qt::FileDialog.getOpenFileName(Qt::Widget,String,String,String filter)"
    signature "static java.util.List Qt::FileDialog.getOpenFileNames(Qt::Widget,String,String,String filter)"
        FileDialog=Proc.new do
          class << self
          #getSaveFileName
            alias orig_getSaveFileName getSaveFileName
            def getSaveFileName(*a)
              args=a.dup
              args[3]=self::Filter.new(args[3]) if args.size==4 && (args[3].kind_of?(String))
              orig_getSaveFileName(*args)
            end
            alias get_save_file_name getSaveFileName
          #getOpenFilename
            alias orig_getOpenFileName getOpenFileName
            def getOpenFileName(*a)
              args=a.dup
              args[3]=self::Filter.new(args[3]) if args.size==4 && (args[3].kind_of?(String))
              orig_getOpenFileName(*args)
            end
            alias get_open_file_name getOpenFileName
          #getOpenFilenames
            alias orig_getOpenFileNames getOpenFileNames
            def getOpenFileNames(*a)
              args=a.dup
              args[3]=self::Filter.new(args[3]) if args.size==4 && (args[3].kind_of?(String))
              orig_getOpenFileNames(*args)
            end
            alias get_open_file_names getOpenFileNames
          end
        end
    #examples\dialogs\standarddialogs
    signature "static Qt::Font Qt:FontDialog.getFont(Qt::Boolean ok)"
    signature "static Qt::Font Qt:FontDialog.getFont(Qt::Boolean ok,Qt::Font)"
    signature "static Qt::Font Qt:FontDialog.getFont(Qt::Boolean ok,Qt::Font,Qt::Widget,String)"
    signature "static Qt::Font Qt:FontDialog.getFont(Qt::Boolean ok,Qt::Widget)"
    signature "static Qt::Font Qt:FontDialog.getFont(Qt::Boolean ok,Qt::Font,Qt::Widget)"
    signature "static Qt::Font Qt:FontDialog.getFont(Qt::Boolean ok,Qt::Font,Qt::Widget,String,Qt::FontDialog::FontDialogOptions)"
        FontDialog=Proc.new do
          class << self
            alias orig_getFont getFont
            def getFont(*a)
              args=a.dup
              if args[0].kind_of? Qt::Boolean
                ok=args.shift
                result=orig_getFont(*args)
                ok.value=result.ok
                result.font
              else
                orig_getFont(*args)
              end
            end
            alias get_font getFont
          end
        end
#examples\draganddrop\fridgemagnets
    signature "Qt::Size Qt::FontMetrics.size(Enum,String)"
    FontMetrics=Proc.new do
      alias :orig_size :size
          def size(*a)
            args=a.dup
            args[0]=args[0].value if args[0].respond_to?(:value)
            orig_size(*args)
          end
      end        
    signature "static java.lang.String Qt::InputDialog.getItem(Qt::Widget parent,String title,String label,java.util.List,int current,bool editable,Qt::Boolean ok)"
    signature "static java.lang.String Qt::InputDialog.getText(Qt::Widget parent,String title,String label,Qt::LineEdit::EchoMode mode,String text,Qt::Boolean ok)"
    signature "static java.lang.String Qt::InputDialog.getInteger(Qt::Widget parent,String title,String label,int value,int minvalue,int maxvalue,int decimals,Qt::Boolean ok)"
    signature "static java.lang.String Qt::InputDialog.getInt(Qt::Widget parent,String title,String label,int value,int minvalue,int maxvalue,int decimals,Qt::Boolean ok)"
    signature "static java.lang.String Qt::InputDialog.getDouble(Qt::Widget parent,String title,String label,Float value,Float minvalue,Float maxvalue,int decimals,Qt::Boolean ok)"
    InputDialog=Proc.new do
      class << self
    #getInt
    #getInteger
        alias orig_getInt getInt
        def getInt(*a)
          args=a.dup
          if args[-1].kind_of? Qt::Boolean
            ok=args.pop
            result=orig_getInt(*args)
            ok.value=(result.nil?) ? false : true
            result
          else
            orig_getInt(*args)
          end
        end
        alias get_int getInt
        alias getInteger getInt
        alias get_integer getInt
    #getDouble
        alias orig_getDouble getDouble
        def getDouble(*a)
          args=a.dup
          if args[-1].kind_of? Qt::Boolean
            ok=args.pop
            result=orig_getDouble(*args)
            ok.value=(result.nil?) ? false : true
            result
          else
            orig_getDouble(*args)
          end
        end
        alias get_double getDouble
    #getItem
        alias :orig_getItem :getItem
        def getItem(*a)
          args=a.dup
          if args[-1].kind_of? Qt::Boolean
            ok=args.pop
            result=orig_getItem(*args)
            ok.value=(result.nil?) ? false : true
            result
          else
            orig_getItem(*args)
          end
        end
        alias get_item getItem
    #getText
        alias :orig_getText :getText
        def getText(*a)
          args=a.dup
          if args[-1].kind_of? Qt::Boolean
            ok=args.pop
            result=orig_getText(*args)
            ok.value=(result.nil?) ? false : true
            result
          else
            orig_getText(*args)
          end
        end
        alias :get_text :getText
      end
    end

    signature "void Qt::Label.setAlignment(Fixnum)"
    Label=Proc.new do
            alias :orig_setAlignment :setAlignment
            def setAlignment(a)
              a=Qt::Alignment.new(a) if a.kind_of?(Fixnum)
              orig_setAlignment(a)
            end
            alias :'alignment=' :setAlignment
    end
    
    #examples\layout\borderlayout
    signature "int Qt::Layout.spacing"
    signature "void Qt::Layout.setSpacing(int)"
        Layout=Proc.new do
          alias :spacing :widgetSpacing
          alias :setSpacing :setWidgetSpacing
          alias :set_spacing :setWidgetSpacing
        end    
    
    signature "void Qt::ListWidgetItem.setTextAlignment(Qt::AlignmentFlag)"
    signature "void Qt::ListWidgetItem.setFlags(int)"

    ListWidgetItem=Proc.new do
            alias :orig_setTextAlignment :setTextAlignment
            def setTextAlignment(a)
              arg=(a.respond_to?(:value)) ? a.value : a
              orig_setTextAlignment(arg)
            end
            alias textAlignment= setTextAlignment
            #examples\draganddrop\puzzle
            alias :orig_setFlags :setFlags
            def setFlags(a)
              arg=(a.kind_of? Fixnum) ? Qt::ItemFlags.new(a) : a
              orig_setFlags(arg)
            end
            alias :set_flags :setFlags
    end
    
    #examples\dialogs\standarddialogs
    signature "static Qt::MessageBox::StandardButton Qt::MessageBox.critical(Qt::Widget,String,String"+
                ",Qt::MessageBox::StandardButton,Qt::MessageBox::StandardButton,Qt::MessageBox::StandardButton)"
    signature "static Qt::MessageBox::StandardButton Qt::MessageBox.question(Qt::Widget,String,String"+
                ",Qt::MessageBox::StandardButton,Qt::MessageBox::StandardButton,Qt::MessageBox::StandardButton)"
        MessageBox=Proc.new do
          class<<self
            alias orig_critical critical
            def critical(*a)
              args=a.dup
              (a.size-4).times{ x=args.pop ; args[-1] |= x}
              orig_critical(*args)
            end
            alias orig_question question
            def question(*a)
              args=a.dup
              (a.size-4).times{ x=args.pop ; args[-1] |= x}
              orig_question(*args)
            end
          end
        end    
    signature "void Qt::Painter.drawText(Qt::Rect,Qt::Alignment,String)"
        Painter=Proc.new do
          alias orig_drawText drawText
          def drawText(*a)
            args=a.dup
            args[1]=args[1].value if (args[1].respond_to?(:value))
            orig_drawText(*args)
          end
          alias draw_text drawText
        end
    
    #examples\draganddrop\dragabletext
        Palette=Proc.new do
          #Background=ColorRole::Window (Background is Obsolete)
          const_set('Background',const_get(:ColorRole).const_get(:Window))
        end
    
    signature "void Qt::ProgressDialog.range=(Range)"
        ProgressDialog=Proc.new do
              def range=(arg)
                if arg.kind_of? Range
                  return setRange(arg.begin, arg.exclude_end?  ? arg.end - 1 : arg.end)
                else
                  return setRange(arg)
                end
              end
        end

    SignalMapper=Proc.new do
      def mapped
        return mappedQObject
      end
    end
     
    signature "static Qt::SizePolicy Qt::SizePolicy.new"
    signature "static Qt::SizePolicy Qt::SizePolicy.new(Qt::SizePolicy::Policy,Qt::SizePolicy::Policy,Qt::SizePolicy::ControlType)"
    signature "static Qt::SizePolicy Qt::SizePolicy.new(Qt::SizePolicy::Policy,Qt::SizePolicy::Policy)"
    signature "static Qt::SizePolicy Qt::SizePolicy.new(int,int,int)"
    signature "static Qt::SizePolicy Qt::SizePolicy.new(int,int)"
        SizePolicy=Proc.new do
          class << self
            alias :orig_new :new
            def new(*args,&block)
              args=args.map{ |arg| arg.kind_of?(Fixnum) ? Qt::SizePolicy::Policy.resolve(arg) : arg}
              return orig_new(*args,&block)
            end
          end
        end
        
    signature "void Qt::SpinBox.range=(Range)"
        SpinBox=Proc.new do
          def range=(arg)
            if arg.kind_of? Range
              return setRange(arg.begin, arg.exclude_end?  ? arg.end - 1 : arg.end)
            else
              return setRange(arg)
            end
          end
        end
    
    #examples\dialogs\findfiles
    signature "void Qt::TableWidgetItem.setFlags(Fixnum flags)"
    signature "void Qt::TableWidgetItem.setTextAlignment(Qt::AlignmentFlag)"
        TableWidgetItem=Proc.new do
          alias orig_setTextAlignment setTextAlignment
          def setTextAlignment(a)
            arg=(a.respond_to?(:value)) ? a.value : a
            orig_setTextAlignment(arg)
          end
          alias textAlignment= setTextAlignment
          alias set_text_alignment setTextAlignment
          
          alias orig_setFlags setFlags
          def setFlags(*a)
            args=a.dup
            args[0]=Qt::ItemFlags.new(args[0]) if args[0].kind_of? Fixnum
            orig_setFlags(*args)
          end
          alias set_flags setFlags
          alias flags= setFlags
        end
    
    signature "void Qt::TextCharFormat.setFontWeight(Qt::Enumerator)"
        TextCharFormat=Proc.new do
          alias :orig_fw :setFontWeight
          def setFontWeight(val)
            orig_fw( (val.respond_to? :value) ? val.value : val)
          end
          alias :set_font_weight :setFontWeight
          alias :'fontWeight=' :setFontWeight
        end

    #require 'jruby/core_ext'
    signature "void Qt::TextStream.<<(String)"
    signature "void Qt::TextStream.>>(String)"
        TextStream=Proc.new do
              def <<(a)
                self.writeString(a)
              end
              def >>(a)
                a.replace(readString)
              end
        end    
    
    signature "static Object Qt::Variant.new(Object)"
    signature "static Object Qt::Variant.fromValue(Object)"
      Variant=Proc.new do
          class << self
            def new(obj=nil)
              return obj
            end
            alias fromValue new
            alias from_value new
          end
      end
  end #Internal

AlignTrailing=AlignRight
AlignLeading=AlignLeft
end #QT

Qt::Internal::signature "void Qt::Object.connect(Qt::Object,Symbol,Qt::Object,Symbol)"
Qt::Internal::signature "void Qt::Object.connect(Qt::Object,Symbol,Qt::Object,String)"
Qt::Internal::signature "void Qt::Object.disconnect(Qt::Object,Symbol,Qt::Object,Symbol)"
Qt::Internal::signature "void Qt::Object.disconnect(Qt::Object,Symbol,Qt::Object,String)"
Qt::Internal::signature "int Qt::Object.qRgba(int,int,int,int)"
Qt::Internal::signature "static java.lang.String Qt::Object.tr(String)"
Qt::Internal::signature "Qt::SignalEmitter Qt::Object.sender"
Java::ComTrolltechQtCore::QObject.class_eval{
#connect(producer,SIGNAL('sig1'),consumer,SLOT('sig2'))
#connect(producer,SIGNAL('sig1'),consumer,SIGNAL('sig2')
#SIGNAL generates :sig1 (Symbol, only name of signal)
#SLOT generates 'sig1(a,b)' (String, full signature)
  def connect(producer,sig1,consumer,sig2,type=0)
    #see if Signal is of type QSignalEmitter  or of type Qt::Signal
    signal1=producer.java_class.field(sig1).value(producer) rescue signal1=producer.send(sig1)
    #puts "connect #{signal1}(#{signal1.class}) => #{sig2}(#{sig2.class}) #{caller[0]}"
    if sig2.kind_of?(String)
      if md=sig2.match(/([^(]+)\([.]*/)
        n=0 ; sig2.gsub(/ (\([^,)]+)|(,[^,)]+) | (,[^,)]+)  /x){n+=1}
        sig2=(n.to_s+md[1].strip)
      end
      #puts "signal->slot #{signal1}.connect(#{consumer},#{sig2.to_sym} #{caller[0]})"
      return signal1.connect(consumer,sig2.to_sym)
    end
    signal2=consumer.java_class.field(sig2).value(consumer) rescue signal2=consumer.send(sig2)
    #puts "signal->signal #{signal1}.connect(#{signal2}) #{caller[0]}"
    return signal1.connect(signal2)
  end
  
  def disconnect(producer,sig1,consumer,sig2)
    if sig2.kind_of?(String) && (md=sig2.match(/([^(]+)\([.]*/))
        n=0 ; sig2.gsub(/ (\([^,)]+)|(,[^,)]+) | (,[^,)]+)  /x){n+=1}
        sig2=(n.to_s+md[1].strip).to_sym
    end
    sig2=sig2.to_sym
    producer.java_class.field(sig1).value(producer).disconnect(consumer,sig2) rescue producer.send(sig1).disconnect(consumer,sig2)
  end
  def sender
    #signalSender ia a static method of QSignalEmitter => Ruby Class Method
    return QtJambi::QSignalEmitter.signalSender()
  end
  #'doc_was_epibrated(a1,a2)' => :'2doc_was_epibrated'
  #'doc_was_cooked()' => :'0doc_was_cooked'
  def SLOT(signature)
    return signature if signature.kind_of? String
    s=signature.to_s
    return s if s.match(/([^(]+)\([.]*/)
    return s+'()'
  end
  def SIGNAL(signature)
    if signature.kind_of? Symbol
      return signature
    else
      if md=signature.match(/([^(]+)\([.]*/)
        return md[1].strip.to_sym
      end
      return signature.to_sym
    end
  end
  
  def self.slots(*signallist) ; end
  #emit signal(a1,a2..)
  def emit(signal)
    signal.emit
  end
  
  def qRgba(*args)
    return Color.new(*args).rgba
  end
  def self.tr(s)
    return self.new.tr(s)
  end
  
}
#try using Qt.Variant type conversions if all else fails
class Object
  def method_missing(m,*args,&block)
    #puts "missing #{m} for #{self.class}  #{caller[0].split('/')[-1]}"
    method=((m==:toBool) || (m==:to_bool)) ? :toBoolean : m
    return Qt::Variant.send(method,self) if com.trolltech.qt.QVariant.respond_to? method
    return super
  end
end

class Class
  
  RX0=/([^(]+)\([.]*/                      #name(.....
  RX1=/\A[A-Z]+\z/                         #1+ alpha => alt_m==m
  RX2=/([A-Z]+)([A-Z][a-z])/               
  RX3=/([a-z\d])([A-Z])/

  def signals(*signallist)
      signallist.each{ |signature|
        if signature.kind_of? String
          if md=signature.match(RX0)
            m=md[1].strip
          else
            m=signature.strip
          end
        else
          m=signature.to_s
        end
        alt_m =(m=~RX1) ? m.downcase : m.gsub(RX2, '\1_\2').gsub(RX3, '\1_\2').tr("-","_").downcase
        self.class_eval(%Q[
          def #{m}(*args)
            if @_#{m}
              @_#{m}.setargs(*args)
              return @_#{m}
            else
              return @_#{m}=Qt::Signal.new(self)
            end
          end
          #{(alt_m==m) ? '' : "alias :#{alt_m} :#{m}"}
        ])
      }

  end
end

class NilClass
  def valid?
    return false
  end
end



