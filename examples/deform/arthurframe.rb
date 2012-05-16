=begin
**
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
** Ruby implementation by by Cees Zeelenberg
=end


class ArthurFrame < Qt::Widget
  
  attr_accessor :descriptionEnabledChanged
  
  def initialize(parent)
    @prefer_image = true
    @show_doc = false
    @document = nil
    @sourceFilename = ""

    @static_image = nil

    

    super(parent)
    @descriptionEnabledChanged = Qt::Signal.new
    @tile = Qt::Pixmap.new(100, 100)
    @tile.fill(Qt::Color.white)
    color = Qt::Color.new(240, 240, 240)
    pt = Qt::Painter.new
    pt.begin(@tile)
    pt.fillRect(0, 0, 50, 50, Qt::Brush.new(color))
    pt.fillRect(50, 50, 50, 50, Qt::Brush.new(color))
    pt.end
  end
  

    def paint(painter)
    super(painter)
    end

  def loadDescription(filename)
    textFile = Qt::File.new(filename)
    if !textFile.open(Qt::File::ReadOnly)
        text = "Unable to load resource file: " + filename
    else 
        ba = textFile.readAll
        codec = Qt::TextCodec.codecForHtml(ba)
        text = codec.toUnicode(ba)
    end
    setDescription(text)
  end

  def setDescription(description)
    @document = Qt::TextDocument.new(self)
    @document.setHtml(description)
  end

  def paintDescription(painter)
    return unless @document

    pageWidth = [width - 100, 100].max
    pageHeight = [height - 100, 100].max
        
    @document.setPageSize(Qt::SizeF.new(pageWidth, pageHeight)) if pageWidth != @document.pageSize.width

    textRect = Qt::Rect.new(width / 2 - pageWidth / 2,
                                   height / 2 - pageHeight / 2,
                                   pageWidth, pageHeight)
    pad = 10
    clearRect = textRect.adjusted(-pad, -pad, pad, pad)
    painter.setPen(Qt::NoPen)
    painter.setBrush(Qt::Brush.new(Qt::Color.new(0, 0, 0, 63)))
    shade = 10

    painter.drawRect(clearRect.x + clearRect.width + 1,
                     clearRect.y + shade,
                     shade, clearRect.height + 1)
    painter.drawRect(clearRect.x + shade, clearRect.y + clearRect.height + 1,
            clearRect.width - shade + 1, shade)
    painter.setRenderHint(Qt::Painter::Antialiasing, false)
    painter.setBrush(Qt::Brush.new(Qt::Color.new(255, 255, 255, 220)))
    painter.setPen(Qt::Color.black)
    painter.drawRect(clearRect)

    painter.setClipRegion(Qt::Region.new(textRect), Qt::IntersectClip)
    painter.translate(textRect.topLeft)

    ctx =Qt::AbstractTextDocumentLayout::PaintContext.new
    g = Qt::LinearGradient.new(0, 0, 0, textRect.height) {
      setColorAt(0, Qt::Color.black)
      setColorAt(0.9, Qt::Color.black)
      setColorAt(1, Qt::Color.transparent)
    }
    pal = Qt::Palette.new
    pal.setBrush(Qt::Palette::Text, Qt::Brush.new(g))
    ctx.setPalette(pal)
    ctx.setClip(Qt::RectF.new(0, 0, textRect.width, textRect.height))
    @document.documentLayout.draw(painter, ctx)
  end

  def loadSourceFile(sourceFile)
    @sourceFilename = sourceFile
  end

  def showSource(tf)
      f = Qt::File.new(@sourceFilename)
      if !f.open(Qt::File::ReadOnly)
        contents = "Could not open file: " + @sourceFilename
      else
        ba = f.readAll
        codec = Qt::TextCodec.codecForLocale
        contents = codec.toUnicode(ba)
      end
      f.close
      contents = contents.gsub("&", "&amp")
      contents = contents.gsub("<", "&lt")
      contents = contents.gsub(">", "&gt")

      keywords=%w(for if switch int const void case double static new this package true false public protected
        private final native import extends implements else class super for)
        
      keywords.each{| keyword|
          contents = contents.gsub(keyword){ |m| "<font color=olive>" + keyword + "</font>"}
      }
      contents = contents.gsub("(int ", "(<font color=olive><b>int </b></font>")
      contents = contents.gsub("(\\d\\d?)", "<font color=navy>$1</font>")

      commentRe = "(//.+)\\n"
      # commentRe.setMinimal(true)
      contents = contents.gsub(commentRe, "<font color=red>$1</font>\n")

      stringLiteralRe = "(\".+\")"
      # stringLiteralRe.setMinimal(true)
      contents = contents.gsub(stringLiteralRe, "<font color=green>$1</font>")

      html = contents
      @html = "<html><pre>" + html + "</pre></html>"

      @sourceViewer = Qt::TextBrowser.new { |v|
        v.setWindowTitle("Source:  + #{@sourceFilename}")
        v.setAttribute(Qt::WA_DeleteOnClose)
        v.setHtml(@html)
        v.resize(600, 600)
        v.show
      }

    end

  def preferImage
      return @prefer_image
  end

  def setPreferImage(pi)
    @prefer_image = pi
  end

  def setDescriptionEnabled(enabled)
    if (@show_doc != enabled) 
      @show_doc = enabled
      @descriptionEnabledChanged.emit(@show_doc)
      update
    end
  end

    #@Override
    def paintEvent(e)
      painter = Qt::Painter.new
      if (preferImage) 
        if @static_image.nil?
          @static_image = Qt::Image.new(size, Qt::Image::Format_RGB32)
        elsif @static_image.size.width != size.width || @static_image.size.height != size.height
          @static_image = Qt::Image.new(size, Qt::Image::Format_RGB32)
        end

        painter.begin(@static_image)
        o = 10

        bg = palette.brush(Qt::Palette::Window)
        painter.fillRect(0, 0, o, o, bg)
        painter.fillRect(width - o, 0, o, o, bg)
        painter.fillRect(0, height - o, o, o, bg)
        painter.fillRect(width - o, height - o, o, o, bg)
      else
        painter.begin(self)
      end

      painter.setClipRect(e.rect)
      painter.setRenderHint(Qt::Painter::Antialiasing)
      
      r = rect
      left = r.x + 1
      top = r.y + 1
      right = r.right
      bottom = r.bottom
      radius2 = 8 * 2

      clipPath = Qt::PainterPath.new{
        moveTo(right - radius2, top)
        arcTo(right - radius2, top, radius2, radius2, 90, -90)
        arcTo(right - radius2, bottom - radius2, radius2, radius2, 0, -90)
        arcTo(left, bottom - radius2, radius2, radius2, 270, -90)
        arcTo(left, top, radius2, radius2, 180, -90)
        closeSubpath
      }

      painter.save
      painter.setClipPath(clipPath, Qt::IntersectClip)
      painter.drawTiledPixmap(rect, @tile)

      paint(painter)

      painter.restore

      painter.save
      
      paintDescription(painter) if (@show_doc)
      painter.restore

      level = 180
      painter.setPen(Qt::Pen.new(Qt::Brush.new(Qt::Color.new(level, level, level)), 2))
      painter.setBrush(Qt::NoBrush)
      painter.drawPath(clipPath)

      if (preferImage)
        painter.end
       painter.begin(self)
        painter.drawImage(e.rect, @static_image, e.rect)
      end

      painter.end
    end




end
