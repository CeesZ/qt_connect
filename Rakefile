#
#  Created by Cees Zeelenberg
#  Copyright (c) 2012. All rights reserved.
#
require 'rake/clean'
require 'rake/gempackagetask'

$:.unshift(File.join(Dir.pwd,"lib"))
require 'qt_connect/version'

task :default => [:jar]
CLEAN.include '*.class','Manifest'
CLOBBER.include '*.jar'

JAVA_FILES=FileList['java/*.java']
CLASS_FILES=JAVA_FILES.pathmap("%n").ext('class')

#directory 'package_dir'

rule '.class' => [proc {|s| x=s.sub(/\.[^.]+$/, '.java') ; 'java/'+x}] do |t|
    sh "javac -target 1.6 #{t.source}"
    puts f=t.source.ext('class')
    verbose(true) { mv "#{f}", "."}
end


desc 'Build the .jar file for the Gem'
task :jar => [CLASS_FILES, 'Manifest']  do
  sh 'jar -cfm lib/signalactions.jar Manifest SignalActions.class'
  rm 'Manifest'
  rm 'Signalactions.class'
end

file 'Manifest' do
  File.open('Manifest','w'){ |f| f.puts "Main-Class: SignalActions"}
end


#~ desc 'Build the Gem package'
#~ task :build_package => [:jar,'package_dir'] do
gem = Gem::Specification.new do |s|
  s.name         ='qt_connect'
  s.version      = QtJambi::Version
  s.date         ='2012-05-16'
  s.summary      ='Uniform Qt bindings for JRuby and Ruby '
  s.authors      =['Cees Zeelenberg']
  s.homepage     = "https://github.com/CeesZ/qt_connect"
  s.email        ='c.zeelenberg@computer.org'
  s.licenses     = ["LGPLv2.1"]
  s.files        =Dir['lib/**/*.rb']
  s.files       +=Dir['java/**/*.java']
  s.files       +=Dir['lib/**/*.jar']
  s.files       +=Dir['examples/**/*.*']
  s.files       +=Dir['[A-Z]*']
  s.require_paths= ["lib"]
  s.description  =
  %Q[Qt bindings for JRuby with (optional) extension to provide backward
  compatibility with Qt Ruby programs. The API is implemented using Qt Jambi, the
  Java version of the Qt framework.  For Qt Ruby programs it provides a QtJambi
  inspired interface to the Signals/Slots system without the need to use
  C++ signatures.
  ]
end

  Rake::GemPackageTask.new(gem) do |pkg|
    #pkg.need_zip = true
    #pkg.need_tar = true
    #pkg.gem_spec = spec
    #pkg.package_files << 'y'
  end
#~ end

