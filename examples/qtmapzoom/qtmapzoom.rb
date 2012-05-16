=begin
**
** Copyright (C) 2009 Nokia Corporation and/or its subsidiary(-ies).
** Contact: Qt Software Information (qt-info@nokia.com)
**
** This file is part of the Graphics Dojo project on Qt Labs.
**
** This file may be used under the terms of the GNU General Public
** License version 2.0 or 3.0 as published by the Free Software Foundation
** and appearing in the file LICENSE.GPL included in the packaging of
** this file.  Please review the following information to ensure GNU
** General Public Licensing requirements will be met:
** http://www.fsf.org/licensing/licenses/info/GPLv2.html and
** http://www.gnu.org/copyleft/gpl.html.
**
** If you are unsure which license is appropriate for your use, please
** contact the sales department at qt-sales@nokia.com.
**
** This file is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING THE
** WARRANTY OF DESIGN, MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
**
** see original article 'Maps with a Magnifying Glass' by Ariya Hidayat
** (http://labs.trolltech.com/blogs/2009/07/29/maps-with-a-magnifying-glass/)
**
** Ruby implementation and minor modifications by Cees Zeelenberg
** (c.zeelenberg@computer.org)
=end

require 'qt_connect'

MAP_HTML=%Q[
<html> 
<head> 
<script type="text/javascript" src="http://maps.google.com/maps/api/js?sensor=false"></script> 
<script type="text/javascript">
  var map;
  function initialize() {
    var myOptions = {
      zoom: 15,
      center: new google.maps.LatLng(51.4772,0.0),
      disableDefaultUI: true,
      mapTypeId: google.maps.MapTypeId.ROADMAP
    }
    map = new google.maps.Map(document.getElementById("map_canvas"),
                                  myOptions);
    var marker = new google.maps.Marker({map: map, position:
        map.getCenter()});
    return true;
  }
</script> 
</head>
<body style="margin:0px; padding:0px;">
    <div id="map_canvas" style="width:100%; height:100%"></div>
    </body></html>
</html> 
  ]
  HOLD_TIME=701
  MAX_MAGNIFIER=229
 #
# the GMaps class should really inherit from Qt:WebView
# but at the time of writing this caused a problem with 'paintEvent', which could not
# provide access to the paint device.
# the disadvantage of this workaround is that keyboard and mouse-events are not passed on
# to the Google application
  
class GMaps < Qt::Widget
  
  def initialize(parent)
    @parent=parent
    super(parent)
    @timer=Qt::Timer.new
    @timer.singleShot=true
    @timer.timeout.connect{triggerLoading}
    @pressed=false
    @snapped=false
    @zoomed=false
    @zoomPage=Qt::WebPage.new(self)
    @zoomPage.repaintRequested.connect{update()}
    @mainPage=Qt::WebPage.new(self)
    
    @mainFrame=@mainPage.mainFrame
    @mainFrame.setScrollBarPolicy(Qt::Vertical, Qt::ScrollBarAlwaysOff)
    @mainFrame.setScrollBarPolicy(Qt::Horizontal, Qt::ScrollBarAlwaysOff)
    content=MAP_HTML
    @mainFrame.setHtml(content)
    @zoomFrame=@zoomPage.mainFrame
    @zoomFrame.setScrollBarPolicy(Qt::Vertical, Qt::ScrollBarAlwaysOff)
    @zoomFrame.setScrollBarPolicy(Qt::Horizontal, Qt::ScrollBarAlwaysOff)
    @zoomFrame.loadFinished.connect{ |tf| triggerLoading}
    content=MAP_HTML.gsub("zoom: 15", "zoom: 16")
    @zoomFrame.setHtml(content)
    @pressPos=Qt::Point.new
    @dragPos=Qt::Point.new
    @tapTimer=Qt::BasicTimer.new
    @zoomPixmap=Qt::Pixmap.new
    @maskPixmap=Qt::Pixmap.new
    @normalPixmapSize=Qt::Size.new

  end
  
  def setCenter(latitude,longitude)
    @lat=latitude
    @lng=longitude
    @dlat=0.0
    @dlng=0.0
    @mousePos=@lastPos
    @code = "map.setCenter(new google.maps.LatLng(#{latitude}, #{longitude}));"
    @mainFrame.evaluateJavaScript(@code)
    @zoomFrame.evaluateJavaScript(@code)
    code = "map.getBounds().toUrlValue(5)"
    return unless coors=(@mainFrame.evaluateJavaScript(code)).toString
    fx1,fy1,fx2,fy2=coors.split(',').map{ |f| f.to_f}
    @dlat=(fx2-fx1)/size.width
    @dlng=(fy2-fy1)/size.height
  end
  
  def setMagnifierMode(mode)
    code=%Q[map.setMapTypeId(google.maps.MapTypeId.#{mode.to_s.upcase});]
    @zoomFrame.evaluateJavaScript(code)
  end
  
  def setPanelMode(mode)
    code=%Q[map.setMapTypeId(google.maps.MapTypeId.#{mode.to_s.upcase});]
    @mainFrame.evaluateJavaScript(code)
  end
  
  def setZoom(zoomfactor)
    code=%Q[map.setZoom(#{zoomfactor});]
    @mainFrame.evaluateJavaScript(code)
    code=%Q[map.setZoom(#{zoomfactor+1});]
    @zoomFrame.evaluateJavaScript(code)
  end
  
  def triggerLoading()
    code = "initialize();"
    xm=@mainFrame.evaluateJavaScript(code).toBool
    xz=@zoomFrame.evaluateJavaScript(code).toBool
    Qt::Timer.singleShot(1000,self,:triggerLoading) unless xm && xz
  end
    
  def timerEvent(event) 
    super(event)
    if (!@zoomed)
        @zoomed = true
        @tapTimer.stop()
        @mainPage.viewportSize=size
        @zoomPage.viewportSize=self.size*2
        lat = @mainFrame.evaluateJavaScript("map.getCenter().lat()").toDouble
        lng = @mainFrame.evaluateJavaScript("map.getCenter().lng()").toDouble
        setCenter(lat, lng);
    end
    update();
  end
  def mousePressEvent(event) 
    @pressed = @snapped = true
    @pressPos = @dragPos = event.pos()
    @tapTimer.stop()
    @tapTimer.start(HOLD_TIME, self)
    super(event)
  end
      
  def mouseReleaseEvent(event) 
    @pressed = @snapped = false
    @tapTimer.stop()
    if (!@zoomed) 
      super(event)
    else
      @zoomed = false
      event.accept()
      update();
    end
end
  def mouseMoveEvent(event)
    @mousePos ||= event.pos
    @lastPos=event.pos()
    if (!@zoomed)
      if (!@pressed || !@snapped)
        begin
        deltamouse=@lastPos-@mousePos
        newlat=@lat+@dlat*deltamouse.y
        newlng=@lng-@dlng*deltamouse.x
        setCenter(newlat,newlng)
        rescue
        end
        return
      else
        threshold=40
        delta = event.pos() - @pressPos
        if (@snapped) 
          @snapped &= (delta.x() < threshold)
          @snapped &= (delta.y() < threshold)
          @snapped &= (delta.x() > -threshold)
          @snapped &= (delta.y() > -threshold)
        end
        (@tapTimer.stop() ; super(event)) if (!@snapped)
      end
    else
      @dragPos = event.pos();
      update();
    end
  end
      
    def paintEvent(event)
      if @normalPixmapSize !=self.size
        @normalPixmapSize=size
        @mainPage.viewportSize=size
        @zoomPage.viewportSize=size * 2
      end
      @painter=Qt::Painter.new(self)
      @painter.renderHint=Qt::Painter::Antialiasing
      @painter.save
      @mainFrame.render(@painter,event.region)
      @painter.restore
      if @zoomed
        dim = [width(), height()].min
        magnifierSize = [MAX_MAGNIFIER, dim * 2 / 3].min
        radius = magnifierSize / 2
        ring = radius - 15
        box = Qt::Size.new(magnifierSize, magnifierSize)

        if (@maskPixmap.size() != box)
          @maskPixmap = Qt::Pixmap.new(box) {fill(Qt::Color.new(Qt::transparent))}
          g=Qt::RadialGradient.new {
            setCenter(radius, radius)
            setFocalPoint(radius, radius)
            setRadius(radius)
            setColorAt(1.0, Qt::Color.new(255, 255, 255, 0))
            setColorAt(0.5, Qt::Color.new(128, 128, 128, 255))
          }
          Qt::Painter.new(@maskPixmap) { |p|
            p.setRenderHint(Qt::Painter::Antialiasing)
            p.setCompositionMode(Qt::Painter::CompositionMode_Source)
            p.setBrush(Qt::Brush.new(g))
            p.setPen(Qt::NoPen)
            p.drawRect(@maskPixmap.rect())
            p.setBrush(Qt::Brush.new(Qt::Color.new(Qt::transparent)))
            p.drawEllipse(g.center(), ring, ring)
            p.end
          }
        end
        center_xy=@dragPos - Qt::Point.new(0,radius/2)
        ulhc_xy = center_xy - Qt::Point.new(radius, radius)
        zoom_ulhc_xy = center_xy * 2 - Qt::Point.new(radius, radius)
        center_xy_f=Qt::PointF.new(center_xy.x.to_f,center_xy.y.to_f)
        
        if (@zoomPixmap.size() != box) 
            @zoomPixmap = Qt::Pixmap.new(box) { fill(Qt::Color.new(Qt::lightGray))}
        end
        Qt::Painter.new(@zoomPixmap) { |zp|
          zp.translate(-zoom_ulhc_xy)
          region=Qt::Region.new(Qt::Rect.new(zoom_ulhc_xy, box))
          @zoomFrame.render(zp,region)
          zp.end
        }
        @clippath=Qt::PainterPath.new{addEllipse(center_xy_f, ring.to_f, ring.to_f)}
        
        @painter.clipPath=@clippath
        @painter.drawPixmap(ulhc_xy, @zoomPixmap)
        @painter.clipping=false
        @painter.drawPixmap(ulhc_xy, @maskPixmap)
        @painter.pen=Qt::gray
        @painter.drawPath(@clippath)
      end
      @painter.end
    end

end

if $0==__FILE__
  
PLACES={ "&Oslo"=>[59.9138204, 10.7387413],
         "&Berlin"=>[52.5056819, 13.3232027],
         "&Jakarta"=>[-6.211544, 106.845172],
         "The &Hague"=>[52.075489,4.309369],
         "&Geelong"=>[-38.1445,144.3710]
    }
MODES=[:hybrid,:roadmap,:satellite,:terrain]
ZOOMRANGE=(14..17)
  
class MapZoom  < Qt::MainWindow
  def initialize
    super
    @map = GMaps.new(self)
    setCentralWidget(@map)
    placeMenu = menuBar().addMenu("&Place")
    placeGroup=Qt::ActionGroup.new(self)
    PLACES.each{ |city,coordinates|
      Qt::Action.new(city, self){ |action|
        action.triggered.connect{@map.setCenter(*coordinates)}
        action.checkable=true
        placeMenu.addAction(action)
      }
    }
    settingsMenu = menuBar().addMenu("&Settings")
    magnifierSubMenu=settingsMenu.addMenu("Magnifier")
    panelSubMenu=settingsMenu.addMenu("Panel")
    zoomSubMenu=settingsMenu.addMenu("Zoomfactor")
    
    magnifierGroup=Qt::ActionGroup.new(self)
    MODES.each{ |mode|
      Qt::Action.new(mode.to_s.capitalize,self){ |action|
        action.triggered.connect{@map.setMagnifierMode(mode)}
        action.checkable=true
        action.checked=true if mode==:roadmap
        magnifierSubMenu.addAction(action)
        magnifierGroup.addAction(action)
      }
    }
    panelGroup=Qt::ActionGroup.new(self)
    MODES.each{ |mode|
      Qt::Action.new(mode.to_s.capitalize,self){ |action|
        action.triggered.connect{@map.setPanelMode(mode)}
        action.checkable=true
        action.checked=true if mode==:roadmap
        panelSubMenu.addAction(action)
        panelGroup.addAction(action)
      }
    }
    zoomGroup=Qt::ActionGroup.new(self)
    ZOOMRANGE.each{ |zoomfactor|
      Qt::Action.new(zoomfactor.to_s,self){ |action|
        action.triggered.connect{@map.setZoom(zoomfactor)}
        action.checkable=true
        action.checked=true if zoomfactor==15
        zoomSubMenu.addAction(action)
        zoomGroup.addAction(action)
      }
    }
  end
end


    a = Qt::Application.new(ARGV)
    w = MapZoom.new
    w.setWindowTitle("Maps (powered by Google)")
    w.resize(600,450)
    w.show()
    a.exec

end