
if RUBY_PLATFORM =~ /java/
  require 'java'
  require 'signalactions.jar'
  require 'qt_connect/qt_jbindings'
else
  raise 'qt_jambi API requires Java platform'
end