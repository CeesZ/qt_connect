if RUBY_PLATFORM =~ /java/
  require 'java'
  require 'signalactions.jar'
  require 'qt_connect/qt_jbindings'
  require 'qt_connect/qt_compat'

else
  require 'Qt'
  require 'qtwebkit'
  require 'qt_connect/qt_sugar'

end