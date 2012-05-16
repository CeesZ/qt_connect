=begin

    Author:     Cees Zeelenberg (c.zeelenberg@computer.org)
    Copyright:  (c) 2010-2012 by Cees Zeelenberg
    License:    This program is free software; you can redistribute it and/or modify  
                it under the terms of the GNU Lesser General Public License as published
                by the Free Software Foundation; either version 2 of the License, or 
                (at your option) any later version.                       *

    This gem can be used to extend the current signals/slots API in QtRuby.
    With this interface there is no need to use C++ signatures or slots on the application level..
    The syntax is similar to the one used in QtJambi (the Java version of the Qt framework):
    Each Signal-emitting Qt class is extended with a method for each Signal it may emit.
    The default name of the method is the same as the signature name. In case of ambiguity
    when the signal has arguments or overloads, the default name for a given signature can be
    overruled through an entry in the Signature2Signal table. The initial entries in the table
    are the same as used in the QtJambi interface.
    
    Example:
    
    button=Qt::PushButton.new
    button.clicked.connect{ puts "Hello World"}   #connecting signal to a Ruby Block
    button.clicked.connect(self,:methodname)      #connecting to receiver/method
    button.clicked.disconnect                     #disconnect all connections originating from this button
    button.clicked.emit                           #can be used to emit the 'clicked' signal (normally
                                                  #generated internally
    label=Qt::Label.new                           #example passing String as argument
    label.linkActivated.connect{ |s| Qt::DesktopServices.openUrl(Qt::Url.new(s))}
    
    Custom components can define their own signals and emit them like this:
    
    signal=Qt::Signal.new
    signal.connect{ |a1,a2| puts "someone send me #{a1} and #{a2}"}
    .
    .
    signal.emit(100,200)
    
=end

require 'Qt'
$VERB=1 if Qt.debug_level==Qt::DebugLevel::Minimal  #minimal debugging
$VERB=2 if Qt.debug_level>Qt::DebugLevel::Minimal   #list Class/Signals info



    
module Qt
  #signal=Qt::Signal.new(pushbutton,'clicked()')        signalemitter can perform (internal) emit; this constructor
  #                                                                      normally used internally
  #signal=Qt::Signal.new                                        only emit through signal.emit             
  class Signal
    def initialize(signalemitter=nil,signature=nil)
      @signature=signature
      @signalemitter=signalemitter
      @actions=[]
    end
    
    # signal1.connect{ |arg1| puts arg1}               connect this signal emitter to a Ruby Block
    # signal1.connect(self,:my_method)                connect this signal emitter to a receiver/method
    #signal1.connect(Qt::Signal signal2)              connect this signal to another (Qt::Signal instance)
    def connect(receiver=nil,method=nil,&block)
      if @signalemitter
        if receiver && (receiver.kind_of?(Qt::Signal))
          @signalemitter.connect(SIGNAL(@signature)){|*args| receiver.emit(*args)}
          return
        end
        @signalemitter.connect(SIGNAL(@signature),receiver,method) if receiver && method
        @signalemitter.connect(SIGNAL(@signature),&block) if block_given?
      else
        @actions << [receiver,method,block]
      end
    end
       
    def emit(*args)
      if @signalemitter
        sig=@signature.gsub(/[(].*[)]/,"").to_sym
        #n.b. arguments passed in a block are passed to the superclass version(e.g. original) of the signal method
        @signalemitter.send(sig){args}
      else
        @actions.each{ |action| receiver,method,block=action
          block.call(*args) if block
          receiver.send(method,*args) if receiver && method
        }
      end
    end
    
    #disconnect()                     disconnects all connections originating in this signal emitter
    def disconnect
      @signalemitter.disconnect(SIGNAL(@signature)) if @signalemitter
      @actions=[]
    end
    
  end
  # support named colors as Class methods: (compatibility QtJambi)
  #e.g. Color.black => Color.new(Qt::black)
  Color.class_eval do
    class << self
      def method_missing(m,*a,&b)
        #puts "Colors missing method #{m}"
        eval "Qt::Color.new(Qt::#{m})"
      end
    end
  end
  Timer.class_eval do
    class << self
      alias :orig_singleShot :singleShot
      def singleShot(timeout,receiver,method)
        if method.kind_of? Symbol
          receiver.class.class_eval{ slots(method.to_s+'()')}
          m=SLOT(method)
        else
          m=method
        end
        orig_singleShot(timeout,receiver,m)
      end
    end
  end


  module Internal
    
    EmbeddedClasses={} #{ 'Qt::WebPage' => ['Qt::WebFrame']}

    # this table overrides the default signature to method name mapping
    #signals mapped to an empty string are ignored

    Signature2Signal={
          
    'Qt::AbstractButton' => {
      'clicked()'       => '',
      'activated(int)'  => ''},
          
    'Qt::AbstractItemDelegate' => {
      'closeEditor(QWidget*)' => ''},

    'Qt::Action' => {
      'triggered()'     => '',
      'activated()'     => '',
      'activated(int)'  => ''},
      
    'Qt::ButtonGroup' => {
      'buttonClicked(int)'  => 'buttonIdClicked',
      'buttonPressed(int)'  => 'buttonIdPressed',
      'buttonReleased(int)' => 'buttonIdReleased'},
          
    'Qt::ComboBox' => {
      'activated(int)'               => 'activatedIndex',
      'highlighted(int)'             => 'highlightedIndex',
      'currentIndexChanged(QString)' => 'currentStringChanged'},

    'Qt::Completer' => {
      'activated(QModelIndex)'   => 'activatedIndex',
      'highlighted(QModelIndex)' => 'highlightedIndex'},

    'Qt::DoubleSpinBox' => {
      'valueChanged(QString)' => 'valueStringChanged'},

    'Qt::GroupBox' => {
      'clicked()'     => ''},

    'Qt::Process' => {
      'finished(int,QProcess::ExitStatus)' => 'finishedWithStatusCode'},

    'Qt::SignalMapper' => {
      'mapped(int)'      => 'mappedInteger',
      'mapped(QString)'  => 'mappedString',
      'mapped(QObject*)' => 'mappedQObject'},

    'Qt::SpinBox' => {
      'valueChanged(QString)' => 'valueStringChanged'},

    'Qt::TabWidget' => {
      'currentChanged(QWidget*)' => ''},

    'Qt::TextBrowser' => {
      'highlighted(QString)' => 'highlightedString'}}
      
    end
end
=begin
  extend the 'new' class method for each Qt Class
  the first time any Qt class is created, it creates new methods for each associated signal
  the signal names are obtained from the metaobject for each class and its superclasses
  e.g the class 'Qt::AbstractListModel' generates a signal: 'dataChanged(QModelIndex,QModelIndex)'
  the first time Qt::AbstractListModel.new is called, the class Qt::AbstractListModel 
  is extended with the method:

  def dataChanged(&block)
    return super(*yield) if block_given?
    return (@_dataChanged ||= Qt::Signal.new(self,'dataChanged(QModelIndex,QModelIndex)')
  end
  alias data_changed dataChanged
  
  the 'super' method is only called when an internally defined signal is emitted externally e.g.
    dataChanged.emit(index1,index2)
    
  this first calls the 'dataChanged' method to obtain the underlying instance of the Signal class and
  then the 'emit' method of Signal calls the same 'dataChanged' method, but with a block argument
  to trigger the same method in the inherited superclass.
  
  (N.B. 'alias', 'respond_to?' and ,'method_defined?' do not find the original signalemitters as methods)
  
  the approach of catching the first instantiation of a Qt class does not work for (the small number)
  of embedded signal emitting classes for which the instances are generated internally by Qt and thus
  the 'new' Ruby class method never is called. To avoid this problem, all classes 'associated' with a class
  being 'activated' are (recursively) also activated. Associated classes are classes of which instances
  are returned by method calls, properties or arguments of signals
  *TODO* a potential problem with this approach is that the MetaObject class does not return all methods of
         a class, but only externally 'invokable' methods. Possible solution is to get this information directly
         from the smoke API if possible.
         
  
=end
Qt::Base.class_eval do
  class << self
    alias new_before_signals new
    def new(*args,&block)
      setup_qt_signals
      new_before_signals(*args,&block)
    end
    
    def setup_qt_signals
        return if @not_first_instance
        @not_first_instance=true
        associates=[]
        printf("\n%-30s (first instance at %s)\n" ,"#{self.name}","#{caller[0].split('/')[-1]}") if $VERB && ($VERB>1)
        signals={}
        begin
          ancestors.each{ |klass| 
            next unless klass.name.start_with?('Qt::')
            begin ; metaobject=klass.staticMetaObject ; rescue ; next ; end
            metaobject.signalNames.each{ |signalname|
              next unless md=signalname.match(/([^ ]+)\ ([^(]+)\(([^)]*)/)  #<returntype><space<methodname>(<args>)
              signature=md[2]+'('+md[3]+')'
              methodname=if (h=Qt::Internal::Signature2Signal[klass.name]) && (mr=h[signature]) ; mr ; else ; md[2] end
              next if methodname.size==0
              next if self.method_defined?(methodname.to_sym)
              printf("  %-30s  =>  %s\n",methodname,signature) if $VERB && ($VERB > 1)
              uscore_name = if (methodname =~ /\A[A-Z]+\z/)
                methodname.downcase
              else
                  methodname.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').tr("-","_").downcase
                end
              #puts "defining #{methodname} for #{self.name} #{self.method_defined? :new} (inherited from #{klass.name})"
              self.class_eval(%Q[
                def #{methodname}(&block)
                  return super(*yield) if block_given?
                  return @_#{methodname} ||=Qt::Signal.new(self,'#{signature}')
                end
                #{(uscore_name==methodname) ? '' : "alias :#{uscore_name} :#{methodname}"}
              ])
            }
            (0...metaobject.propertyCount).each{ |i| associates |= [metaobject.property(i).typeName]}
            (0...metaobject.methodCount).each{ |m| method=metaobject.method(m)
              case method.methodType
              when Qt::MetaMethod::Signal
                if md=method.signature.match(/([^(]+)\(([^)]*)/)
                  associates |= md[2].split(',').map{ |s| s.delete('*&<>')}
                end
              else
                associates |= [method.typeName] if method.typeName.size>0
              end
            }
          }
        rescue => e
          puts e if $VERB
        end
        x=associates.map{|c| Qt::Internal::normalize_classname(c)}.                 #normalized names e.g. QWebFrame => Qt::WebFrame
            select{ |c| c.start_with?('Qt::')}.                                      #remove non-Qt classes
            each{ |klassname| eval("#{klassname}.setup_qt_signals") rescue next }   #recursive call to setup associates signals
        #(Internal::EmbeddedClasses["#{self.name}"] || []).each{ |klassname| eval("#{klassname}.setup_qt_signals")}
      end


  end

end
