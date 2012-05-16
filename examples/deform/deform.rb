=begin
** Copyright (C) 1992-2009 Nokia. All rights reserved.
**
** This file is part of Qt Jambi.
**
** ** $BEGIN_LICENSE$
** Commercial Usage
** Licensees holding valid Qt Commercial licenses may use this file in
** accordance with the Qt Commercial License Agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and Nokia.
** 
** GNU Lesser General Public License Usage
** Alternatively, this file may be used under the terms of the GNU Lesser
** General Public License version 2.1 as published by the Free Software
** Foundation and appearing in the file LICENSE.LGPL included in the
** packaging of this file.  Please review the following information to
** ensure the GNU Lesser General Public License version 2.1 requirements
** will be met: http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html.
** 
** In addition, as a special exception, Nokia gives you certain
** additional rights. These rights are described in the Nokia Qt LGPL
** Exception version 1.0, included in the file LGPL_EXCEPTION.txt in this
** package.
** 
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU
** General Public License version 3.0 as published by the Free Software
** Foundation and appearing in the file LICENSE.GPL included in the
** packaging of this file.  Please review the following information to
** ensure the GNU General Public License version 3.0 requirements will be
** met: http://www.gnu.org/copyleft/gpl.html.
** 
** If you are unsure which license is appropriate for your use, please
** contact the sales department at qt-sales@nokia.com.
** $END_LICENSE$

**
** This file is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING THE
** WARRANTY OF DESIGN, MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
**
** Translated to QtRuby by Cees Zeelenberg
=end

require 'qt_connect'
require 'arthurframe'


class PainterPathElements
  attr_accessor :path,:elements
  def initialize
    @path=nil
    @elements=[]
  end
end

class PathDeformRenderer < ArthurFrame
  
  attr_accessor :animated,:radius,:fontSize,:intensity,:text

def initialize(parent)
    @repaintTimer =Qt::BasicTimer.new
    @repaintTracker = Qt::Time.new
    @paths = []
    @advances = []
    @pathBounds = Qt::RectF.new
    @text = ""
    @lens_pixmap = nil
    @lens_image = nil
    @fontSize = 0
    @animated = false

    @textDirty = true;
    super(parent)
    @radius = 100
    @pos = Qt::PointF.new(@radius, @radius)
    @direction = Qt::PointF.new(1, 1)
    @fontSize = 24
    @animated = true;
    @repaintTimer.start(100, self)
    @repaintTracker.start
    @intensity = 1
    generateLensPixmap
    end

  def fontSize=(fontSize) 
    @fontSize = fontSize
    self.text=@text
  end
  
  def sizeHint
    return Qt::Size.new(600, 500)
  end

  def text=(text)
    @text = text
    @textDirty = true
    update
  end

  def makeTextPaths
    f = Qt::Font.new("times new roman,utopia")
    f.setStyleStrategy(Qt::Font::ForceOutline)
    f.setPointSize(@fontSize)
    f.setStyleHint(Qt::Font::Times)
    

    fm = Qt::FontMetrics.new(f)
    @paths=[]
    @pathBounds = Qt::RectF.new
    advance = Qt::PointF.new(0, 0)
    paths = []

    do_quick = true;

    if (do_quick)
      @text.each_char{ |c|
        path = Qt::PainterPath.new
        path.addText(advance, f, c)
        @pathBounds = @pathBounds.united(path.boundingRect)
        paths << path
        advance+=Qt::PointF.new(fm.width(c), 0)
      }
    else 
      path = Qt::PainterPath.new
      path.addText(advance, f, @text)
      @pathBounds = @pathBounds.united(path.boundingRect)
      paths << path
    end

    m = Qt::Matrix.new(1, 0, 0, 1, -@pathBounds.x, -@pathBounds.y)
    paths.each{ |path| addPath(m.map(path)) }
    @textDirty = false;
  end

  def addPath(path)
    p = PainterPathElements.new
    p.path = path
    (0...path.elementCount).each{ |i| p.elements.push(path.elementAt(i))}
    @paths << p
  end

  def circle_bounds(center,radius,compensation)
        return Qt::Rect.new((center.x - radius - compensation).round,
                         (center.y - radius - compensation).round,
                         ((radius + compensation) * 2).round,
                         ((radius + compensation) * 2).round)
  end


    LENS_EXTENT = 10;
  def generateLensPixmap
    rad = @radius + LENS_EXTENT

    bounds = circle_bounds(Qt::PointF.new, rad, 0)

    painter = Qt::Painter.new
    if (preferImage) 
        @lens_image = Qt::Image.new(bounds.size, Qt::Image::Format_ARGB32_Premultiplied)
        @lens_image.fill(0)
        painter.begin(@lens_image)
    else
        @lens_pixmap = Qt::Pixmap.new(bounds.size)
        @lens_pixmap.fill(Qt::Color.new(0, 0, 0, 0))
        painter.begin(@lens_pixmap)
    end

    gr = Qt::RadialGradient.new(rad, rad, rad, 3 * rad / 5, 3 * rad / 5) {
      setColorAt(0.0, Qt::Color.new(255, 255, 255, 191))
      setColorAt(0.2, Qt::Color.new(255, 255, 127, 191))
      setColorAt(0.9, Qt::Color.new(150, 150, 200, 63))
      setColorAt(0.95, Qt::Color.new(0, 0, 0, 127))
      setColorAt(1, Qt::Color.new(0, 0, 0, 0))
    }

    painter.setRenderHint(Qt::Painter::Antialiasing)
    painter.setBrush(Qt::Brush.new(gr))
    painter.setPen(Qt::NoPen)
    painter.drawEllipse(0, 0, bounds.width, bounds.height)
    painter.end
  end

  def setAnimated(animated)
    @animated = animated;

    if (@animated) 
        @repaintTimer.start(25, self)
        @repaintTracker.start
    else
        @repaintTimer.stop
    end
  end

  def paintEvent(e)
    makeTextPaths if (@textDirty)
    super(e)
  end

  def timerEvent(e)
    if (e.timerId == @repaintTimer.timerId) 
      if ((Qt::LineF.new(Qt::PointF.new(0,0), @direction)).length > 1)
          @direction*=0.995
      end

      time = @repaintTracker.restart

      rectBefore = circle_bounds(@pos, @radius, @fontSize)

      dx = @direction.x
      dy = @direction.y

      if time > 0
          dx = dx * time * 0.1;
          dy = dy * time * 0.1;
      end

      @pos+=Qt::PointF.new(dx, dy)

        if @pos.x - @radius < 0
            @direction.x=-@direction.x
            @pos.x=@radius
        elsif @pos.x + @radius > width
            @direction.x=-@direction.x
            @pos.x=width - @radius
        end

        if @pos.y - @radius < 0
            @direction.y=-@direction.y
            @pos.y=@radius
        elsif @pos.y + @radius > height
            @direction.y=-@direction.y
            @pos.y=height - @radius
        end

        rectAfter = circle_bounds(@pos, @radius, @fontSize)
        #update(rectBefore.united(rectAfter))
        update(rectBefore|rectAfter)
        Qt::Application.syncX
    end
  end

  #@Override
  def mousePressEvent(e)
    setDescriptionEnabled(false)

    @repaintTimer.stop
    @offset = Qt::PointF.new

    if (Qt::LineF.new(@pos, Qt::PointF.new(e.pos))).length <= @radius
      @offset = Qt::PointF.new(@pos.x, @pos.y)
      @offset.subtract(Qt::PointF.new(e.pos))
    end

    mouseMoveEvent(e)
  end

  #@Override
  def mouseReleaseEvent(e)
    if e.buttons.isSet(Qt::MouseButton::NoButton) && @animated
      @repaintTimer.start(25, self)
      @repaintTracker.start
    end
  end

  #@Override
  def mouseMoveEvent(e)
    rectBefore = circle_bounds(@pos, @radius, @fontSize)
      if e.type == Qt::Event::Type::MouseMove
          epos = Qt::PointF.new(e.pos)
          epos.add(@offset)
          line = Qt::LineF.new(@pos, epos)
          line.setLength(line.length * 0.1)
          dir = Qt::PointF.new(line.dx, line.dy)
          @direction.add(dir)
          @direction.multiply(0.5)
      end

      @pos = Qt::PointF.new(e.pos)
      @pos.add(@offset)
      rectAfter = circle_bounds(@pos, @radius, @fontSize)

      update(rectBefore.united(rectAfter))
  end

  def deformElement(e, offset, pts)
    flip = @intensity;

    x = e.x + offset.x
    y = e.y + offset.y

    dx = x - @pos.x
    dy = y - @pos.y
    len = @radius - Math.sqrt(dx * dx + dy * dy)

    if len > 0
        x += flip * dx * len / @radius;
        y += flip * dy * len / @radius;
      end
      
    pts[0] = x;
    pts[1] = y;
  end

  def lensDeform(source, offset)
    path = Qt::PainterPath.new
    pts = []
    skip=0
    c1x=c2x=c1y=c2y=0
    source.elements.each{ |e|
      case skip
      when 0
        if e.isLineTo
            deformElement(e, offset, pts)
            path.lineTo(pts[0], pts[1])
        elsif e.isMoveTo
            deformElement(e, offset, pts)
            path.moveTo(pts[0], pts[1])
        elsif e.isCurveTo
            deformElement(e, offset, pts)
            c1x = pts[0]; c1y = pts[1];
            skip=2
        end
      when 2
        deformElement(e, offset, pts)
        c2x = pts[0]; c2y = pts[1];
        skip=1
      when 1
        deformElement(e, offset, pts)
        ex = pts[0]; ey = pts[1];
        path.cubicTo(c1x.to_f, c1y.to_f, c2x.to_f, c2y.to_f, ex.to_f, ey.to_f)
        skip=0
      end
    }
    return path
  end

  #@Override
  def paint(painter)
    pad_x = 5
    pad_y = 5
    skip_x = (@pathBounds.width + pad_x + @fontSize / 2).round
    skip_y = (@pathBounds.height + pad_y).round

    painter.setPen(Qt::NoPen)
    painter.setBrush(Qt::Brush.new(Qt::Color.black))

    clip = painter.clipPath.boundingRect
    overlap = pad_x / 2;

        (0...height).step(skip_y){ |start_y|
          break if start_y > clip.bottom
            start_x=-overlap
            (-overlap...width).step(skip_x){ |sx|
            start_x=sx
                if (start_y + skip_y >= clip.top &&
                  start_x + skip_x >= clip.left &&
                  start_x <= clip.right)
                    @paths.each{ |p|
                        path = lensDeform(p, Qt::PointF.new(start_x, start_y))
                        painter.drawPath(path)
                    }
                end
            }
            overlap = skip_x - (start_x - width)
        }
        if (preferImage) 
            painter.drawImage((@pos.x - @radius - LENS_EXTENT).to_i,(@pos.y - @radius - LENS_EXTENT).to_i, @lens_image)
        else
            painter.drawPixmap((@pos.x - @radius - LENS_EXTENT).to_i,(@pos.y - @radius - LENS_EXTENT).to_i, @lens_pixmap)
        end
    end

  def radius=(radius)
      max = [@radius, radius].max
      @radius = radius;
      generateLensPixmap
      update(circle_bounds(@pos, max, @fontSize)) if !@animated || @radius < max
    end

  def intensity=(intensity)
      @intensity = intensity / 100.0
      update(circle_bounds(@pos, @radius, @fontSize)) if (!@animated)
  end
end
#@QtJambiExample(name = "Deform")
class Deform < Qt::Widget

  def initialize
    super

    setWindowTitle("Vector deformation")
    setWindowIcon(Qt::Icon.new("qt-logo.png"))

    @renderer = PathDeformRenderer.new(self)
    #@renderer.setSizePolicy(Qt::SizePolicy::Policy::Expanding, Qt::SizePolicy::Policy::Expanding)

    mainGroup = Qt::GroupBox.new(self) {
      setTitle("Vector Deformation")
      setFixedWidth(180)
    }

    radiusGroup = Qt::GroupBox.new(mainGroup) {
      setTitle("Lens radius")
    }
    
    radiusSlider = Qt::Slider.new(Qt::Horizontal, radiusGroup) {
      setRange(50, 150)
      setSizePolicy(Qt::SizePolicy::Preferred, Qt::SizePolicy::Fixed)
    }

    deformGroup = Qt::GroupBox.new(mainGroup) {
      setTitle("Deformation")
    }
    
    deformSlider = Qt::Slider.new(Qt::Horizontal, deformGroup) {
      setRange(-100, 100)
      setSizePolicy(Qt::SizePolicy::Preferred, Qt::SizePolicy::Fixed)
    }

    fontSizeGroup = Qt::GroupBox.new(mainGroup) {
      setTitle("Font Size")
    }
    
    fontSizeSlider = Qt::Slider.new(Qt::Horizontal, fontSizeGroup) {
      setRange(16, 200)
      setSizePolicy(Qt::SizePolicy::Preferred, Qt::SizePolicy::Fixed)
    }

    textGroup = Qt::GroupBox.new(mainGroup) {
      setTitle("Text")
    }

    textInput = Qt::LineEdit.new(textGroup)

    animateButton = Qt::PushButton.new(mainGroup) {
      setText("Animated")
      setCheckable(true)
    }

    showSourceButton = Qt::PushButton.new(mainGroup) {
      setText("Show Source")
    }

    whatsThisButton = Qt::PushButton.new(mainGroup) {
      setText("What's This?")
      setCheckable(true)
    }

    mainLayout = Qt::HBoxLayout.new(self) { |l|
      l.addWidget(@renderer)
      l.addWidget(mainGroup)
    }
    

    mainGroupLayout = Qt::VBoxLayout.new(mainGroup) {
      addWidget(radiusGroup)
      addWidget(deformGroup)
      addWidget(fontSizeGroup)
      addWidget(textGroup)
      addWidget(animateButton)
      addStretch(1)
      addWidget(showSourceButton)
      addWidget(whatsThisButton)
    }

    radiusGroupLayout = Qt::VBoxLayout.new(radiusGroup) { addWidget(radiusSlider) }

    deformGroupLayout = Qt::VBoxLayout.new(deformGroup) { addWidget(deformSlider) }

    fontSizeGroupLayout = Qt::VBoxLayout.new(fontSizeGroup) { addWidget(fontSizeSlider) }

    textGroupLayout = Qt::VBoxLayout.new(textGroup) { addWidget(textInput) }

    textInput.textChanged.connect{ |str| @renderer.text=str}
    radiusSlider.valueChanged.connect{ |r| @renderer.radius=r}
    deformSlider.valueChanged.connect{ |i| @renderer.intensity=i}
    fontSizeSlider.valueChanged.connect{ |i| @renderer.fontSize=i}
    animateButton.clicked.connect{ |tf| @renderer.setAnimated(tf)}
    whatsThisButton.clicked.connect(@renderer, :setDescriptionEnabled)
    showSourceButton.clicked.connect(@renderer, :showSource)
    @renderer.descriptionEnabledChanged.connect(whatsThisButton, :setChecked)

    animateButton.animateClick
    deformSlider.setValue(80)
    radiusSlider.setValue(100)
    fontSizeSlider.setValue(100)
    textInput.setText("Qt Jambi")

    #@renderer.loadSourceFile("classpath:com/trolltech/demos/Deform.java")
    @renderer.loadSourceFile("deform.rb")
    @renderer.loadDescription("deform.html")
    @renderer.setDescriptionEnabled(false)
  end
end


    
    app=Qt::Application.new(ARGV)
    w = Deform.new
    w.show
   app.exec

