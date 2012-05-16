if RUBY_PLATFORM =~ /java/
  require 'qt_connect'
else
  begin
    require 'Qt4'
  rescue LoadError
    raise "qt_connect for Ruby requires the qtbindings gem installed "
  end
  require 'qt_connect'
end