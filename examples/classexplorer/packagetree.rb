#encoding: utf-8
require 'qt_connect'

#Scans all classes accessible from JRuby runtime classloader
#Cees Zeelenberg (c.zeelenberg@computer.org)
#partially adapted from: snippets.dzone.com/posts/show/4831  (Java)
#N.B. filters out selected classes specific to QtJambi !!!

#PackageTree#keys     => [packagename + subpackage names]
#PackageTree#values  => [all packages in tree]
#PackageTree['packagename'] => package
#Package#classes => [classnames in package]
#Cees Zeelenberg

#Get all classes within a package
class PackageTree < Hash
  
  class Package
    attr_accessor :classes,:innerclasses,:path,:parent,:children
    def initialize(packagetree,package_name)
      @package_name=package_name
      @packagetree=packagetree
      @classes=[]
      @children=[]
      pp=package_name.split('.').slice(0...-1).join('.')
      @parent=(pp.size>0) ? (packagetree[pp] || Package.new(packagetree,pp)) : nil
      @parent.children << self if @parent
    end
  end
    
  def initialize(root_package_name)
    @root_package_name=root_package_name
    @packages=super()
    @packages[root_package_name]= Package.new(self,root_package_name)
    @jars={}
    path=@root_package_name.gsub('.','/')
    class_loader=JRuby.runtime.jruby_class_loader
    resources=class_loader.getResources(path)
    dirs=[]
    while resources.hasMoreElements
      resource=resources.nextElement
      dirs << resource.getFile
    end
    classpaths=[]
    dirs.each{ |dir| classpaths += findClasses(dir,@root_package_name)}
    classpaths.uniq.each{ |klasspath| 
      next if klasspath.end_with?('$ConcreteWrapper')
      next if klasspath.end_with?('$QtJambi_LibrariInitializer')
      next if klasspath.end_with?('$1') #anonymous inner class?
      elems=klasspath.split('.')
      klass=elems.pop
      package_name=elems.join('.')
      @packages[package_name]=package=@packages[package_name] || Package.new(self,package_name)
      package.classes << klass
    }
  end
  
  def jars
    return @jars.keys.join(',')
  end
  
  def findClasses(path,package_name)
    classes=[]
    if path.start_with?("file:") && path.include?("!")
      split=path.split("!")
      jar=java.net.URL.new(split[0])
      @jars[split[0][6..-1]]=true
      zip=java.util.zip.ZipInputStream.new(jar.openStream)
      while entry=zip.getNextEntry
        if entry.getName.end_with?(".class")
          class_name=entry.getName.gsub(/[.]class/,'').gsub('/','.')
          classes << class_name if class_name.start_with?(package_name)
        end
      end
    end
    dir=java.io.File.new(path)
    return classes if !dir.exists
    dir.listFiles.each{ |file|

      if file.isDirectory
        raise 'hell' if file.include?('.')
        classes += findClasses(file.getAbsolutePath, package_name + '.' + file.getName)
      elsif file.getName.end_with?(".class")
        classes += Java::Class.forName(package_name + '.' + file.getName[0..-7])
      end
    }
    return classes
  end
end


