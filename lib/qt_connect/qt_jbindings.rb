=begin

    Author:     Cees Zeelenberg (c.zeelenberg@computer.org)
    Copyright:  (c) 2010-2012 by Cees Zeelenberg
    License:    This program is free software; you can redistribute it and/or modify  
                it under the terms of the GNU Lesser General Public License as published
                by the Free Software Foundation; either version 2 of the License, or 
                (at your option) any later version.
                
  Provides the basic Ruby bindings for the Qt Jambi Java classes and an interface to the
  Signals and Slots mechanism. Appropriate classes are extended with overloaded operators
  such as +, - , | and &. Both Ruby-ish underscore and Java-ish camel case naming for
  methods can be used. Like with QtRuby, constructors can be called in a conventional
  style or with an initializer block. If you want an API which follows closely the QtJambi
  documentation and programming examples all you need to do is 'require qt_jambi'. A
  minimalist example to display just a button which connects to a website when clicked:

      require 'qt_jambi'
        
      app=Qt::Application.new(ARGV)
      button=Qt::PushButton.new( "Hello World")
      button.clicked.connect{ Qt::DesktopServices.openUrl(Qt::Url.new('www.hello-world.com'))}
      button.show
      app.exec 

  If you want more compatibility with QtRuby, use:
      require 'qt_connect'
    
=end
$VERB=false
include Java
include_class Java::SignalActions

module Qt
  module Internal
    #define here which packages to include
    Packages=%w{
      com.trolltech.qt
      com.trolltech.qt.core
      com.trolltech.qt.gui
      com.trolltech.qt.network
      com.trolltech.qt.opengl
      com.trolltech.qt.phonon
      com.trolltech.qt.sql
      com.trolltech.qt.svg
      com.trolltech.qt.webkit
      com.trolltech.qt.xml
      com.trolltech.qt.xmlpatterns
    }
    #keep track of RUBY extensions for classexplorer
    RUBY_extensions=[]
    
    def signature(*args)
      RUBY_extensions.concat(args)
    end
    #allow the use of 'signature' within this module
    extend self
    alias :signatures :signature
  end
end



module QtJambi
  Qt::Internal::Packages.each { |pkg| include_package pkg}
  ABSTRACTSIGNAL=QSignalEmitter::AbstractSignal.java_class
  SIGNALEMITTERS={
    QSignalEmitter::Signal0 => 'signal0()',
    QSignalEmitter::Signal1 => 'signal1(Object)',
    QSignalEmitter::Signal2 => 'signal2(Object,Object)',
    QSignalEmitter::Signal3 => 'signal3(Object,Object,Object)',
    QSignalEmitter::Signal4 => 'signal4(Object,Object,Object,Object)',
    QSignalEmitter::Signal5 => 'signal5(Object,Object,Object,Object,Object)',
    QSignalEmitter::Signal6 => 'signal6(Object,Object,Object,Object,Object,Object)',
    QSignalEmitter::Signal7 => 'signal7(Object,Object,Object,Object,Object,Object,Object)',
    QSignalEmitter::Signal8 => 'signal8(Object,Object,Object,Object,Object,Object,Object,Object)',
    QSignalEmitter::Signal9 => 'signal9(Object,Object,Object,Object,Object,Object,Object,Object,Object)',
  }

end
  # AbstractSignal is the QtJambi class which implements the functionality to emit signals
  # it interoperates with a matching Ruby Qt:Signal class
  # here we extend the existing AbstractSignal 'connect' method with the ability to connect to
  #either a Ruby block or a Ruby Object method through an instance of the RubySignalAction class
  #the signature for the connect is derived from the underlying Signal class (e.g. Signal0..Signal9)
  #SignalEmitters can also be connected to other SignalEmitters (eiher inheriting from the QtJambi
  #AbstractSignal class or the Ruby Signal class)

  #A: QtJambi::AbstractSignal#connect{ |*args| .......}                                connect this signal emitter to a Ruby Block
  #B: QtJambi::AbstractSignal#connect(self,:my_method)                            connect this signal emitter to a receiver/method
  #C: QtJambi::AbstractSignal#connect(Qt::Signal signal2)                         connect this signal to a Qt::Signal instance
  #D: QtJambi::AbstractSignal#connect(QtJambi::AbstractSignal signal2)    connect this signal to another QtJambi::AbstractSignal instance

  QtJambi::QSignalEmitter::AbstractSignal.class_eval{
      alias :orig_connect :connect
      def connect(a1=nil,a2=nil,&block)
        if a1
          if QtJambi::SIGNALEMITTERS[a1.class]
            orig_connect(a1)                                       #connecting [D]
            return
          end
          
          if a1.kind_of?(Qt::Signal)
            @action=Qt::RubySignalAction.new{ |*a| a1.emit(*a)}
            orig_connect(@action,'signal0()')                       #connecting [C]
            return
          end
        end
        #
        if signature=QtJambi::SIGNALEMITTERS[self.class]
          @action=Qt::RubySignalAction.new(a1,a2,&block)
          orig_connect(@action,signature)                            #connecting  [A,B]
          return
        else
          raise "cannot connect signal #{self} to #{a1}"
          return
        end
      end
  }
  
module Qt
  include com.trolltech.qt.core.Qt

  class Signal
    def initialize(sender=nil)
      @actions=[]
      @args=nil
      @sender=sender
    end
    
    #E:  Qt::Signal#connect{ |*args| .........  }                                  connect this signal emitter to a Ruby Block
    #F:  Qt::Signal#connect(self,:my_method)                                 connect this signal emitter to a receiver/method
    #G:  Qt::Signal#connect(Qt::Signal signal2)                              connect this signal to another Qt::Signal instance
    #H:  Qt::Signal#connect(QtJambi::AbstractSignal signal2)          connect this signal to a QtJambi::AbstractSignal instance
    
    def connect(a1=nil,a2=nil,&block)
      if (a1 && (a1.kind_of?(Qt::Signal))) ||
            (a1.respond_to?(:java_class) &&
            (a1.java_class.superclass==QtJambi::ABSTRACTSIGNAL))
        @actions << Qt::RubySignalAction.new{ |*args| a1.emit(*args)}   #connecting [G,H]
        return
      end
      @actions << Qt::RubySignalAction.new(a1,a2,&block)                 #connecting [E,F]
    end
    
    def setargs(*args)
      @args=args
    end
    
    #(Qt::Signal signal).emit(*args)
    def emit(*args)
      @args=args if args.size>0 || @args.nil?
      @actions.each{ |action| action.emit(@args) }
      @args=nil
    end
    
    #disconnect()                     disconnects all connections originating in this signal emitter
    #disconnect(object)            disconnects all connections made from this signal emitter to a specific receiver
    #disconnect(object,method)  disconnects all connections made from this signal emitter to a specific receiver method
    def disconnect(a1=nil,a2=nil,&block)
      @actions.map{ |action|
        next action if a1 && (action.receiver != a1) 
        next action if a2 && (action.method != a2) 
        next action if block_given? && (action.block != block) 
        action.receiver=nil
        action.method=nil
        action.block=nil
        nil
      }
      @actions.compact!
    end
    
  end


# RubySignalAction is the Ruby class which implements the functionality to activate
# a Ruby Block or Object Method as a result of a Qt emitted Signal
#the Ruby method names match the names of the Java interface SignalActions:
#(see SignalActions.java)

    class RubySignalAction < QtJambi::QObject
    include SignalActions
    attr_accessor :receiver, :method, :block
    def initialize(receiver=nil,method=nil,&block)
      super()
      @receiver=receiver
      @method=method
      @block=block
      @args=[]
    end
    
    def append_args(*args)
      @args=args
    end
    
    #generate the Ruby method names to match the names of the Java interface SignalAction
    #e.g.  def signal6(a1,a2,a3,a4,a5,a6,a7) ; emit([a1,a2,a3,a4,a5,a6]) ; end        
    #e.g.  def signal7(a1,a2,a3,a4,a5,a6,a7) ; emit([a1,a2,a3,a4,a5,a6,a7]) ; end        
    QtJambi::SIGNALEMITTERS.values.each{ |signature|
      i=0
      s1=signature.gsub(/Object/){ |m| i+=1 ; "a#{i}"}
      s2=s1.gsub(/signal\d\(/,"emit([").gsub(')','])')
      eval "def #{s1} ; #{s2} ; end"
    }

    def emit(a)
      args=a+@args
      n=nil
      if @method && (md=@method.to_s.match(/([0-9]*)(.+)/x)) #??????????????????
        n=md[1].to_i unless md[1]==''
        @method=md[2].gsub('()','').to_sym
      end
      if (m=args.size)>0
        @block.call(*args) if @block
        if @receiver && @method
          #cap the number of arguments to number wanted by receiver
          #e.g. triggered uses signal1 iso signal0 as in example
          n ||=@receiver.method(@method).arity
          if (n==0)
            @receiver.send(@method)
          else
            args.slice!(0,n) if (m>n) && (n>0)
            @receiver.send(@method,*args)
          end
        end
      else
        @block.call if @block
        @receiver.send(@method) if @receiver && @method
      end
    end
  end 

  class << self
    #come here on missing constant in the Qt namespace
    #if the missing name maps to an existing QtJambi class, equate the missing constant to that class and
    # - make Signal fields accessable to Ruby methods
    # - define a 'new' classmethod with optional iterator block initialization
    # - define 'shorthand' constants to be compatible with qtbindings (optional, require 'qt_compat.rb' )
    # - monkeypatch the underlying class with extensions defined in Qt::Internal (optional, require 'qt_compat.rb' )
    def const_missing(name)
      qtclass = QtJambi.const_get("Q#{name}") rescue qtclass = QtJambi.const_get("Qt#{name}") rescue qtclass = QtJambi.const_get("#{name}")
      qtclass.class_eval do        if self.class==Class # no constructor for modules
          class << self
            def new(*args,&block)
              instance=self.allocate
              instance.send(:initialize,*args)
              if block_given?
                if block.arity == -1 || block.arity == 0
                  instance.instance_eval(&block)
                elsif block.arity == 1
                  block.call(instance)
                else
                  raise ArgumentError, "Wrong number of arguments to block(#{block.arity} ; should be 1 or 0)"
                end
              end
              return instance
            end
          end
        end
      #Ruby extensions for a class are stored in Qt::Internal as Procs with the same name as the class
      #the signature for each extension is logged in Qt::Internal::RUBY_extensions (for documentation only)
      #see examples in qt_compat.rb
      if Qt::Internal.const_defined?(name)
        puts "include extension #{name}" if $VERB
        self.class_eval(&Qt::Internal.const_get(name))
      end

    end
    const_set(name, qtclass)
    Qt.create_constants(qtclass,"Qt::#{name}") if Qt.respond_to? :create_constants
    Qt.setup_qt_signals(qtclass)
    return qtclass
    end
      
    end
    
    #qtclass         # => Java::ComTrolltechQtCore::QPoint (Class)
    # JRuby exposes Java classes fields as Ruby instance methods, class methods or constants.
    # there is a problem with the implementation of Signals in Jambi in that there is a
    # (public) Java field and  (private) Java methods with the same name (e.g. clicked)
    #we want to access the field, but get the method. The logic here defines a new method which acesses the field
    #this is done for the Qt class being activated PLUS all Qt signal emitting  classes for which this class may
    #return instances (e.g. Qt::WebPage also activates Qt::WebFrame because Qt::WebPage.mainPage returns an
    #instance of Qt::WebFrame which is a signalemitter)
    @@activated={}
    def Qt.setup_qt_signals(qtclass)
      return if @@activated[qtclass.java_class.name]
      org.jruby.javasupport.JavaClass.getMethods(qtclass).to_a.
        map{ |jm| returnclass=jm.getReturnType}.
        select{ |jc| jc.getClasses.to_a.include? QtJambi::ABSTRACTSIGNAL}.
        map{ |jc| jc.getName}.
        uniq.
        delete_if{ |jn| @@activated[jn]}.
        each { |klassname| klass=eval(klassname)
          klass.class_eval do
            next if @@activated[java_class.name]
            java_class.fields.each do |field|
              next unless field.type.superclass==QtJambi::ABSTRACTSIGNAL
              puts "     #{java_class.name} fieldname: #{field.name} fieldtype: #{field.type.to_s}" if $VERB
              uscore_name = if (field.name =~ /\A[A-Z]+\z/)
                field.name.downcase
              else
                field.name.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').tr("-","_").downcase
              end
              self.class_eval %Q[
                def #{field.name}(*args, &block)
                  #puts '===> #{klass.name}.#{field.name} <=> #{field.type.to_s} -1-'
                  return self.java_class.field(:#{field.name}).value(self)
                end
                #{(uscore_name==field.name) ? '' : "alias :#{uscore_name} :#{field.name}"}
              ]
            end
            @@activated[java_class.name]=true
          end
          
        }
        #@@activated[qtclass.java_class.name]=true
      end
  

  module Internal       #namespace Qt::Internal


#bitwise operations on an enumerator:
#return a Flag object if a Flag creation class is defined for this object (in table QtJambi::Flag)
#otherwise return an integer value
#'other' object must be integer or respond_to value method
QtJambi::QtEnumerator.class_eval{
  def |(other) ; int_op(other) { |a,b| a|b} ; end
  def &(other) ; int_op(other) { |a,b| a&b} ; end
  def ^(other) ; int_op(other) { |a,b| a^b} ; end
  def ~ ; unary_op{ |a| ~a} ; end

  def ==(other)
    o=other.respond_to?(:value) ? other.value : other
    self.value==o
  end
  
  def to_i
    return value
  end
  def to_int
    return value
  end
    #~ def coerce(other)
        #~ [(other.respond_to?(:value)) ? other.value : other, value]
    #~ end
  private
  
  def unary_op
    r=yield(value)
    return self.class.new(r) if self.class.ancestors.include? com.trolltech.qt.QFlags
    begin
      obj=self.class.createQFlags(self)
      obj.value=r
      return obj
    rescue
      return r
    end
  end
  
  def int_op(other)
    r=yield(value,other.respond_to?(:value) ? other.value : other)
    return self.class.new(r) if self.class.ancestors.include? com.trolltech.qt.QFlags
    return other.class.new(r) if other.class.ancestors.include? com.trolltech.qt.QFlags
    begin
      obj=self.class.createQFlags(self)
      obj.value=r
      return obj
    rescue
    end
    begin
      obj=other.class.createQFlags(self)
      obj.value=r
      return obj
    rescue
      #raise ArgumentError, "operation not defined between #{self.class} and #{other.class}"
      return r
    end
  end
}
########################################################
signature "Qt::Line Qt::Line.*Qt::Matrix"
signature "Qt::LineF Qt::LineF.*Qt::Matrix"
signature "boolean Qt::Line.==Qt::Line"
signature "boolean Qt::LineF.==Qt::LineF"
[QtJambi::QLine,QtJambi::QLineF].each{ |javaclass| javaclass.class_eval{
    def ==(other) ; (x1==other.x1) && (y1==other.y1) &&
    (x2==other.x2) && (y2==other.y2)  ; end
    def *(other) return other.map(self) if other.kind_of?(Qt::Matrix) ; end
    def <<(a); writeString(a) ; end
    def >>(a) ; a.replace(readString) ; end
  }
}

signature "boolean Qt::Matrix.==Qt::Matrix"
signature "Qt::Matrix Qt::Matrix.*Qt::Matrix"
QtJambi::QMatrix.class_eval{
    def ==(other) ; (m11==other.m11) && (m12==other.m12) &&
      (m21==other.m21) && (m22==other.m22)  &&
    (dx==other.dx) && (dy==other.dy) ; end
    def *(other) ; clone.multiply(other) ; end
    #~ def =(other) ; self.m11=other.m11 ; self.m12=other.m12
                     #~ self.m21=other.m21 ; self.m22=other.m22
                     #~ self.dx=other.dx ; self.dy=other.dy ; end
}

signature "Qt::PainterPath Qt::PainterPath.&Qt::PainterPath"
signature "Qt::PainterPath Qt::PainterPath.|Qt::PainterPath"
signature "Qt::PainterPath Qt::PainterPath.+Qt::PainterPath"
signature "Qt::PainterPath Qt::PainterPath.-Qt::PainterPath"
signature "Qt::PainterPath Qt::PainterPath.*Qt::Matrix"
QtJambi::QPainterPath.class_eval{
    def &(other) ;  operator_and(other) ; end
    def |(other) ;  operator_or(other) ; end
    def +(other) ;  operator_add(other) ; end
    def -(other) ;  operator_subtract(other) ; end
    def *(other) return other.map(self) if other.kind_of?(Qt::Matrix) ; end
    def <<(a); writeString(a) ; end
    def >>(a) ; a.replace(readString) ; end
}

signature "boolean Qt::Point.==Qt::Point"
signature "Qt::Point Qt::Point.+Qt::Point"
signature "Qt::Point Qt::Point.-Qt::Point"
signature "Qt::Point Qt::Point./double"
signature "Qt::Point Qt::Point.*double"
signature "Qt::Point Qt::Point.-@Qt::Point"
signature "boolean Qt::PointF.==Qt::PointF"
signature "Qt::PointF Qt::PointF.+Qt::PointF"
signature "Qt::PointF Qt::PointF.-Qt::PointF"
signature "Qt::PointF Qt::PointF./double"
signature "Qt::PointF Qt::PointF.*double"
signature "Qt::PointF Qt::PointF.-@Qt::PointF"
[QtJambi::QPoint,QtJambi::QPointF].each{ |javaclass| javaclass.class_eval{
    def ==(other) ; (x==other.x) && (y==other.y) ; end
    def +(other) ;  clone.add(other) ; end
    def -(other) ;  clone.subtract(other) ; end
    def -@ ; cl=clone ; cl.setX(-x) ; cl.setY(-y) ; cl ; end
    def /(other) ;  clone.divide(other) ; end
    def *(other) ;  clone.multiply(other) ; end
    def <<(a); writeString(a) ; end
    def >>(a) ; a.replace(readString) ; end
    
    }
}

signature "Qt::Polygon Qt::Polygon.*Qt::Matrix"
signature "Qt::PolygonF Qt::PolygonF.*Qt::Matrix"
[QtJambi::QPolygon,QtJambi::QPolygonF].each{ |javaclass| javaclass.class_eval{
    def *(other) return other.map(self) if other.kind_of?(Qt::Matrix) ; end
}

signature "Qt::Rect Qt::Rect.&Qt::Rect"
signature "Qt::Rect Qt::Rect.|Qt::Rect"
signature "boolean Qt::Rect.==Qt::Rect"
signature "Qt::RectF Qt::RectF.&Qt::RectF"
signature "Qt::RectF Qt::RectF.|Qt::RectF"
signature "boolean Qt::RectF.==Qt::RectF"
[QtJambi::QRect,QtJambi::QRectF].each{ |javaclass| javaclass.class_eval{
    def &(other) ;  clone.intersected(other) ; end
    def |(other) ;  clone.united(other) ; end
    def ==(other) ; (x==other.x) && (y==other.y) && (width==other.width) && (height==other.height) ; end
    def <<(a); writeString(a) ; end
    def >>(a) ; a.replace(readString) ; end
    }
  }
}

signature "Qt::Region Qt::Region.&Qt::Region"
signature "Qt::Region Qt::Region.|Qt::Region"
signature "Qt::Region Qt::Region.+Qt::Region"
signature "Qt::Region Qt::Region.-Qt::Region"
signature "Qt::Region Qt::Region.-@Qt::Region"
signature "boolean Qt::Region.==Qt::Region"
QtJambi::QRegion.class_eval{
    def ==(other) ; (x==other.x) && (y==other.y) ; end
    def &(other) ;  clone.intersected(other) ; end
    def |(other) ;  clone.united(other) ; end
    def +(other) ;  operator_add(other) ; end
    def -(other) ;  clone.subtracted(other) ; end
    def -@ ; clone.setX(-x).setY(-y) ; end
    #def /(other) ;  clone.divide(other) ; end
    #def *(other) ;  clone.multiply(other) ; end
    def <<(a); writeTo(a) ; end
    def >>(a) ; a.replace(readString) ; end
}

signature "Qt::Size Qt::Size.*Numeric"
signature "Qt::Size Qt::Size./Numeric"
signature "Qt::Size Qt::Size.+Qt::Size"
signature "Qt::Size Qt::Size.-Qt::Size"
signature "boolean Qt::Size.==Qt::Size"
QtJambi::QSize.class_eval{
    def ==(other) ; (height==other.height) && (width==other.width) ; end
    def +(other) ;  add(other) ; end
    def -(other) ;  subtract(other) ; end
    def /(other) ;  divide(other) ; end
    def *(other) ;  multiply(other) ; end
}

# addAction(Icon,String text)
#addAction(Icon,String text,java.lang.Object receiver, java.lang.String method)                                            <= 4 n=2
# addAction(Icon,  String text, java.lang.Object receiver, java.lang.String method, Qt::KeySequence shortcut)  <= 5 n=2
# addAction(Icon,  String text, QSignalEmitter.AbstractSignal signal) <= 3
# addAction(Icon,  String text, QSignalEmitter.AbstractSignal signal, Qt::KeySequence shortcut)                   <= 4
# addAction(String text)
# addAction(String text, java.lang.Object Receiver,  java.lang.String method)                                                 <= 3 n=1
# addAction(String text, java.lang.Object Receiver,  java.lang.String method, Qt::KeySequence shortcut)           <= 4 n=1
# addAction(String text, QSignalEmitter.AbstractSignal signal)
# addAction(String text, QSignalEmitter.AbstractSignal signal, Qt::KeySequence shortcut)<= 3 n=
# map (receiver,method) combinations
signature "Qt::Action Qt::Menu.addAction(Qt::Icon, String, Object, Symbol rubymethod)"
signature "Qt::Action Qt::Menu.addAction(Qt::Icon, String, Object, Symbol rubymethod,Qt::KeySequence)"
signature "Qt::Action Qt::Menu.addAction(String, Object, Symbol rubymethod)"
signature "Qt::Action Qt::Menu.addAction(String, Object, Symbol rubymethod,Qt::KeySequence)"
QtJambi::QMenu.class_eval {
    alias :orig_addAction :addAction
    def addAction(*a)
      args=a.dup
      n=0
      if args.size > 2
        if args[0].kind_of?(String)
          n=1 if args[2].kind_of?(String)
        else
          n=2 if (args.size > 3) && (args[3].kind_of?(String))
        end
      end
      if n>0
        @rubysignalactions ||= []
        @rubysignalactions << Qt::RubySignalAction.new(args[n],args[n+1])
        args[n]=@rubysignalactions[-1]
        args[n+1]='signal0()'
        #args[0]=args[0].value if args[0].respond_to?(:value)
      end
      orig_addAction(*args)
    end
}

# addAction(Icon, text)
# addAction(Icon, text, receiver, method)     <=  n=2
# addAction(Icon, text, signal)                    <= n=0
# addAction(text)
# addAction(text, receiver, method)             <=  n=1
# addAction(text, signal)
# map (receiver,method) combinations
signature "Qt::Action Qt::ToolBar.addAction(Qt::Icon, String, Object rubyreceiver, Symbol rubymethod)"
signature "Qt::Action Qt::ToolBar.addAction(String, Object rubyreceiver, Symbol rubymethod)"
QtJambi::QToolBar.class_eval {
    alias :orig_addAction :addAction
    def addAction(*a)
      args=a.dup
      n=0
      if args.size > 2
        if args[0].kind_of?(String)
          n=1
        else
          n=2 if args.size==4
        end
      end
      if n>0
        @rubysignalactions ||= []
        @rubysignalactions << Qt::RubySignalAction.new(args[n],args[n+1])
        args[n]=@rubysignalactions[-1]
        args[n+1]='signal0()'
      end
      orig_addAction(*args)
    end
}

# addAction(text)
# addAction(text, receiver, method)       <= 
# addAction(text, signal)
# map (receiver,method) combinations
signature "Qt::Action Qt::MenuBar.addAction(String, Object rubyreceiver, Symbol rubymethod)"
QtJambi::QMenuBar.class_eval {
    alias :orig_addAction :addAction
    def addAction(*a)
      args=a.dup
      if args.size > 2
        @rubysignalactions ||= []
        @rubysignalactions << Qt::RubySignalAction.new(args[1],args[2])
        args[1]=@rubysignalactions[-1]
        args[2]='signal0()'
      end
      orig_addAction(*args)
    end
}

# singleShot(timeout,receiver,method)
# map (receiver,method) combinations
#N.B singleShot is a Qt::Timer class method
#so there is only one instance of class Class
signature "static void Qt::Timer.singleShot(Fixnum msecs, Object rubyreceiver, Symbol rubymethod)"
QtJambi::QTimer.class_eval {
  class << self
    alias :orig_singleShot :singleShot
    def singleShot(timeout,receiver,method)
      method =(md=method.match(/([^(]+)\([.]*/)) ? md[1].to_sym : method.to_sym unless method.kind_of? Symbol
        @pendingactions ||= []
        action=Qt::RubySignalAction.new(self,:_singleShot)
        action.append_args(action,receiver,method)
        @pendingactions << action
        orig_singleShot(timeout,action,'signal0()')
    end
      
    def _singleShot(action,receiver,method)
      receiver.send(method)
      @pendingactions.delete(action)
    end
      
  end
}

#Some classes do not like to be initialized with nil
#compatibility with legacy software
[QtJambi::QWidget,QtJambi::QLayout].each{ |klass| klass.class_eval{
      alias :orig_initialize :initialize
      def initialize(*args)
        if ((args.size==0) || ((args.size==1) && args[0].nil?))
          orig_initialize()
        else
          orig_initialize(*args)
        end
      end
  }
}
    signature "static Qt::Application Qt::Application.new(Array)"
    signature "static java.lang.String Qt::Application.translate(java.lang.String,java.lang.String,java.lang.String,Qt::Enumerator)"
    signature "static java.lang.String Qt::Application.translate(java.lang.String,java.lang.String)"
    Application=Proc.new do
          class << self
            #QAppplication has only a single instance, which needs to be initialized
            #in an uninitialized object unexpected things don't work
            #e.g. it can't process plug-ins like jpeg
            #java_send used to avoid confusion with Ruby initialize constructor
            def new(args,&block)
              java_send(:initialize,[java.lang.String[]],args.to_java(:string))
              $qApp=self
              if block_given?
                if block.arity == -1 || block.arity == 0
                  instance_eval(&block)
                elsif block.arity == 1
                  block.call(self)
                else
                  raise ArgumentError, "Wrong number of arguments to block(#{block.arity} ; should be 1 or 0)"
                end
              end
              return self
            end
            
            alias :orig_translate :translate
            def translate(context,sourcetext,comment=nil,encoding=nil)
              if encoding
                int=(encoding.respond_to? :value) ? encoding.value : encoding
                orig_translate(context,sourcetext,comment,int)
              else
                orig_translate(context,sourcetext)
              end
            end
   
          end
    end
  end #Module Internal
end #Module Qt

