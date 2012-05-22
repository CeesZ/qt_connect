qt\_connect
==========

This project provides a Qt programming API for JRuby with a high degree of compatibility 
with the existing Qt interface for Ruby. The API is implemented using Qt Jambi, the Java version
of the Qt framework. The interface consists of two software components: the actual Ruby
bindings (qt\_jambi) and a compatibility layer (qt\_compat) which makes it easier to run
existing Qt Ruby code using JRuby.  
A third component (qt\_sugar) introduces the Qt Jambi signals interface to QtRuby. With this interface
there is no need to use C++ signatures or slots on the application level.  
The three components are packaged in a single, pure-Ruby gem package 'qt\_connect'. The same gem
can be installed on Ruby and JRuby installations.

### prerequisites and usage
**Ruby**
>*prerequisite:* qtbindings Ruby gem package  
>>download from: <http://github.com/ryanmelt/qtbindings>  
>>installation: follow qtbindings instructions

>`require 'qt_connect'` to use Qt Jambi Signals interface   

**JRuby**  
>*prerequisite:* qtjambi Java library     
>>download from: <http://qt-jambi.org>  
>>installation: install two jar-files on CLASSPATH (e.g. C:/jruby-1.6.7/lib or /usr/lib/jruby/lib)  
>>qtjambi-`<version>`.jar (e.g. qtjambi-4.7.1.jar)  
>>qtjambi-`<platform>`-`<version>`.jar (e.g. qtjambi-win32-msvc2008-4.7.1.jar)

>`require 'qt_jambi'` for basic Qt Jambi bindings only  
>`require 'qt_connect'` for Qt Jambi bindings + QtRuby compatibility layer


### tested environments

**[Windows 7 Home Premium]**
>ruby 1.9.1p429 [i386-mingw32]  
> qtbindings-4.6.3.2-x86-mingw32  
> qt_connect-1.5.1  
>  
>jruby 1.6.7 [Windows 7-x86-java]  
>qtjambi-4.7.1.jar  
>qtjambi-win32-msvc2008-4.7.1.jar  
>qt\_connect-1.5.1

**[Mac OS X]**
>jruby 1.6.7 [darwin-i386-java]  
>qtjambi-4.7.0.jar  
>qtjambi-macosx-gcc-4.7.0.jar  
>qt\_connect-1.5.1

>>Note: You need to use a 32-bit JVM because the qtjambi binaries are 32-bit only for the moment.
>>You can do this by opening the "Java Preferences" application and drag the system 32-bit JVM at the top
>>
>>You also need to set up the right environment: classpath, java options, ...
>>You might want to use this script:
>>
>> ``` bash
#!/bin/sh
QJ=path/to/qtjambi-macosx-community-4.7.0
export CLASSPATH=$QJ/qtjambi-4.7.0.jar:$QJ/qtjambi-macosx-gcc-4.7.0.jar:.
export JAVA_OPTS="-XstartOnFirstThread -Djava.library.path=$QJ/lib"
export QT_PLUGIN_PATH=$QJ/plugins
JRUBY=path/to/jruby/bin/jruby
$JRUBY -rubygems $@
```

**[Linux : ubuntu 11:10]**
>ruby 1.8.7p352 [x86_64-linux]  
>qtbindings-4.6.3.4  
>qt\_connect-1.5.1  
>  
>jruby 1.5.1p249 [amd64-java]  
>qtjambi-4.7.0.jar  
>qtjambi-linux64-gcc-4.7.0.jar  
>qt\_connect-1.5.1  
          
>>Note: Under Ubuntu I could only run the programs using administrator privilege
>>e.g. sudo jruby ..... My Linux expertise is limited but it seems that
>>the operating system itself uses the Qt library and that maybe jruby loads (part of)
>>the qtjambi library not from the jar but from somewere else on the loadpath. I have
>>the same problem with the QtJambi demo programs if I just install QtJambi (nothing
>>to do with JRuby). Any help would be appreciated.
          
  
qt\_jambi
--------
Provides the basic Ruby bindings for the Qt Jambi Java classes and an interface to the
Signals and Slots mechanism. Appropriate classes are extended with overloaded operators
such as +, - , | and &. Both Ruby-ish underscore and Java-ish camel case naming for
methods can be used. Like with Qt Ruby, constructors can be called in a conventional
style or with an initializer block. If you want an API which follows closely the QtJambi
documentation and programming examples all you need to do is `'require qt_jambi'`. A
minimalist example to display just a button which connects to a website when clicked:

    require 'qt_jambi'

    app=Qt::Application.new(ARGV)
    button=Qt::PushButton.new( "Hello World")
    button.clicked.connect{ Qt::DesktopServices.openUrl(Qt::Url.new('www.hello-world.com'))}
    button.show
    app.exec`


The QtJambi documentation contains a large number of examples written in Java. Even with
a moderate knowledge of Java it is fairly easy to translate these to Ruby or
use them as examples for new Ruby programs.
                
qt\_compat
---------
A compatibility layer which can be installed on top of the 'qt\_jambi' bindings.
Including this layer makes it possible to run existing Qt Ruby code with no or only minor
modifications using JRuby.  
Since the QtJambi API is build on the same underlying C++ library as the Qt Ruby API, the
Qt(C++) classes are mostly mapped to equivalent Qt Jambi(Java/Ruby) and Qt Ruby(Ruby)
classes. The majority of Ruby classes exposed through the Qt Jambi API are therefore
identical to the classes exposed through the Qt Ruby API. There are however differences
due to different language capabilities and limitations in converting C++ types to Java and
Ruby 'types'. The two most notable differences are the handling of Enums and the abstract
value type QVariant

### Enums
Enums are used widely throughout the Qt framework, mostly as integer constants and
bit flags. Using Qt Jambi, Java Enums are accessible through JRuby as constants. Individual
values are accessed combining namespace with enum type name and enum value name:

      Qt::Alignment::AlignCenter
      Qt::Alignment::AlignLeft
      Qt::Font::StyleHint::Times
      Qt::Font::StyleStrategy::ForceOutline

QtRuby accesses the same values using a shorthand notation omitting the type name:
    
      Qt::AlignCenter
      Qt::AlignLeft
      Qt::Font::Times
      Qt::Font::ForceOutline
      
Using the compatibility layer the same shorthand notation constants are defined in addition
to the existing ones. If the shorthand notation clashes with other entries or existing class
names, the default mapping can be overruled.

### QVariant
The Qt API provides an abstract value type, QVariant, which can hold values of many
C++ and Qt types. In Java - like Ruby - there is no real need for such a type because
the language already provides Object as an abstract type. This works because all Java
classes inherit Object. For that reason, the Qt Jambi API uses Object where Qt uses
QVariant.  
To maintain code compatibility with QtRuby a dummy constructor method
is defined which basically returns the original object unchanged:

      size=Qt::Size.new(100,200)
      variant=Qt::Variant.new(size)                   #=> size

This works in many cases, but not always. QtRuby code using the Qt::Variant class may
need to be adjusted for use with the QtJambi bindings. 


### Slots and Signals
Although QtJambi supports a simpler mechanism to deal with signals which does not need
the C++ signatures and uses methods or code blocks in stead of slots, a full set of compatible
routines to handle Slots and Signals is included for compatibility with QtRuby. This includes
slots and signals functions, SLOT and SIGNAL 'macros', connect, disconnect, emit and sender
methods:

      slots 'documentWasModified()'
      signals 'contentsChanged()'
      
      connect(@textEdit.document(), SIGNAL('contentsChanged()'),
                  self, SLOT('documentWasModified()'))

      emit contentsChanged
      
### Custom adjustments
A number of individual class definitions are 'tweaked' or extended to make the QtRuby API
fit on the QtJambi API. This is still very much work in progress
                  
qt\_sugar 
--------
  
Provides added functionality to the current signals/slots API in QtRuby
It avoids the need to use C++ signatures and signal/slots functions in applications.
The syntax is similar to the one used in QtJambi (the Java version of the Qt framework):
Each Signal-emitting Qt class is extended with a method for each Signal it may emit.
The default name of the method is the same as the signature name. In case of ambiguity
when the signal has arguments or overloads, the default name for a given signature can be
overruled through an entry in the **Signature2Signal** table. The initial entries in the table
are the same as used in the QtJambi interface.  
Example:


      require 'qt_connect'
    
      button=Qt::PushButton.new
    
    #connecting signal to a Ruby Block:
      button.clicked.connect{ puts "Hello World"}
    
    #connecting to receiver/method
      button.clicked.connect(self,:methodname)
    
    #disconnect all connections originating from this button
      button.clicked.disconnect

    #emitting the signal (normally done internally by Qt)
      button.clicked.emit
      
    #example passing String as argument
      label=Qt::Label.new                                   
      label.linkActivated.connect{ |s| Qt::DesktopServices.openUrl(Qt::Url.new(s))}
    
Custom components can define their own signals and emit them like this:
    
    @signal=Qt::Signal.new
    @signal.connect{ |a1,a2| puts "someone send me #{a1} and #{a2}"}
    .
    .
    @signal.emit(100,200)
    
background
-----------
For several years I have been an enthusiastic user of the excellent Ruby bindings to the Qt APIs as provided
by Richard Dale and others as part of the Korundum/QtRuby project. With the becoming of age of JRuby
I became interested in running my applications using JRuby, mainly for reasons of packaging and deployment. 
The [qtjruby-core gem](https://github.com/nmerouze/qtjruby-core)  provided by Nicolas Merouze
was a good start for a JRuby interface to QtJambi, but to get a reasonable compatibility with an existing
code base in QtRuby a lot more was required. I decided therefore to develop a new gem package which
would make it easy to port existing applications to JRuby or better use the same code for deployment
under Ruby and JRuby.
Because of the inherent differences between the two interfaces it will never be possible to have complete inter
operability, but it is certainly possible to write code in such a way that it will work with both Ruby and JRuby.
As a proof of principle I have a large Qt application (>10000 lines Ruby Code) which runs with the 'qt\_connect'
gem both under Ruby and JRuby. This allows me to do development under Ruby and package and deploy under JRuby.

Through the years I have seen several suggestions for changes to the slots and signals interface used by QtRuby.
The existing API is based on C++ signatures and not very appropriate for Ruby programming. The solution
provided by the QtJambi interface is quite elegant and in my opinion also suitable for Ruby. I have therefore included a
QtJambi based signals interface for Ruby programs in the gem package.
 
### examples and testing
The example programs should run both in a Ruby (qtbindings + qt\_connect gem packages) and a JRuby
(qt\_connect gem + Qt Jambi jars) setting. The Class Explorer is for JRuby users only.
This browser extends the Javadoc  documentation for the com.trolltech.qt Javapackages that
form the basis for the JRuby Qt Jambi API.
If you install the Ruby qtbindings gem package, the example directory includes more than 75 example programs.
Of these programs about a third run unchanged with JRuby and the qt\_connect gem. Of the remaining programs
quite a few can not run for the same reason in that they make use of the Qt's resources system which is different
from the Qt Jambi resource management (these are all the examples using files with the .qrc extension). Some programs
run after minor modifications and more may run with appropriate extensions of the qt\_compat module, I have not had
much time to test this out.
  
### packaging and deployment
When it comes to packaging your Qt JRuby application, there is a great gem package to help you called
[Rawr](http://rawr.rubyforge.org). With Rawr, a simple, pre-generated configuration file turns your code into
an executable jar, a .exe for Windows, and a .app for OS X.
  
### documentation
If you install the full Qt Jambi package, it comes with extensive documentation for the Java API and a large number
of Java demonstration programs. Use these together with the class explorer program (*part of this gem package*) to write
your Ruby programs.
The example programs (*deform.rb*, *qtmapzoom.rb* and *classexplorer.rb*) also show how to program the signal interface
in Ruby.
For Qt Ruby programming in general have a look at the demonstration programs included with the qtbindings gem package.
There is also an ebook 
([Rapid GUI Development with QtRuby](http://pragprog.com/book/ctrubyqt/rapid-gui-development-with-qtruby)
by Caleb Tennis) published by The Pragmatic Bookshelf. Although the book itself is somewhat out of date,  it is still a good introduction
to Qt Ruby programming.
In addition to the [Qt Jambi documentation](http://doc.trolltech.com/qtjambi-4.4/html) there is also a lot of Qt documentation
online at the [Qt Developer Network](http://qt-project.org).
For information about JRuby look at <http://jruby.org> , read the [JRuby Cookbook](http://shop.oreilly.com/product/9780596519650.do)
published by O'Reilly or [Using JRuby](http://pragprog.com/book/jruby/using-jruby)  from The Pragmatic Bookshelf.  
  
## license
 
Copyright &copy; 2010-2012 Cees Zeelenberg (<c.zeelenberg@computer.org>)  
This software is released under the LGPL Version 2.1.
See COPYING.LIB.txt  
