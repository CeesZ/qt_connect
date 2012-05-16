# encoding: utf-8
module Menus
  class HelpMenu
    
    def initialize(window,menubar)
      @window=window
      Qt::Menu.new(menubar) { |helpMenu|
        menubar.addAction(helpMenu.menuAction)
        helpMenu.title="Help"
        # Help> Contents
        Qt::Action.new(window) { |action|
          action.text="Contents"
          action.icon=window.style.standardIcon(Qt::Style::SP_DesktopIcon)
          
          action.triggered.connect { Qt::MessageBox.about(window,'Qt_connect',contents)}
          helpMenu.addAction(action)
        }
        helpMenu.addSeparator
        #Help> About Qt
        Qt::Action.new(window) { |action|
          action.text="About Qt"
          action.triggered.connect { Qt::MessageBox.aboutQt(window) } #$qApp.aboutQt}
          helpMenu.addAction(action)
        }
        helpMenu.addSeparator
        #Help> About Qt Jambi
        Qt::Action.new(window) { |action|
          action.text="About Qt Jambi"
          action.triggered.connect { $qApp.aboutQtJambi } #$qApp.aboutQt}
          helpMenu.addAction(action)
        }
      }
    end
    
    def contents
%Q[
<html><h1>Qt_Connect Class Explorer</h1>
<font size="+1">
<p>This browser extends the Javadoc documentation for the <b>com.trolltech.qt</b> Java packages that form
the basis for the JRuby Qt Jambi API.</p>
<p>The left hand top frame displays all packages found on the Java CLASSPATH which implement the Qt framework.
You can select one or more of these packages for inspection. By default all packages are selected.<br/>
The lower panel displays all Classes and Interfaces which belong to the selected packages mapped to
the same Ruby <b>Qt</b> namespace.</p>
<p>The mapping rules from full-package name for each class in Java to Ruby namespace 
are simple: when a class name starts with either 'Qt' or 'Q' that part of the name is dropped, otherwise it is unchanged.</p>
Examples:</p>
<table cellpadding="3" cellspacing="0">
<tr><td>com.trolltech.qt.QSysInfo</td><td>Qt::SysInfo</td></tr>
<tr><td>com.trolltech.qt.Utilities</td><td>Qt::Utilities</td></tr>
<tr><td>com.trolltech.qt.gui.QToolButton</td><td>Qt::ToolButton</td></tr>
<tr><td>com.trolltech.qt.svg.QSvgWidget</td><td>Qt::SvgWidget</td></tr>
<tr><td>com.trolltech.qt.QtEnumerator</td><td>Qt::Enumerator</td></tr>
</table>
<p>The number of classes displayed can be narrowed down by entering a filter value in the bottom field</p>
<p>The next panel displays a summary for the selected Class or Interface from the JRuby perspective: Java fields and methods
are mapped to Ruby Constants, Class Methods and Instance Methods. Fields inheriting the SignalEmitter class are
separately listed as <b>Signals</b> with prototypes of the methods or blocks they can connect to.</p>
<p>Constants which inherit the Qt::Enumerator module are separately listed as <b>Enums</b> with their enumerated values and shorthand
notations.</p>
<p>In the right-hand top of the panel a box can be ticked to include or exclude members of inherited Qt classes. If you tick the
<em>'link to Qt Jambi Reference Documentation'</em> box, a separate (dockable) window opens displaying the matching Javadoc documentation.
If you use this feature, make sure the Javadoc root url matches the version of Qt Jambi you have installed.</p>
<p>


</p></font></html>
      ]
    end
  end
end

    