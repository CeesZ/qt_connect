#
#Qt::LineEdit
#extended with Clearbutton Icon in right handcorner (SP_BrowserStop)
#extended with Placeholdertext in Grey when empty and not in focus
#functionality (partially?) added for Qt 4.7

module QtExtensions
  class LineEdit < Qt::LineEdit
    def setClearButton
      @clearButton=Qt::ToolButton.new(self){ |b|
        b.icon=style.standardIcon(Qt::Style::SP_BrowserStop)
        b.iconSize=Qt::Size.new(16,16)
        b.cursor=Qt::Cursor.new(Qt::ArrowCursor)
        b.styleSheet="border:none; padding: 0px;"
        b.hide
        b.clicked.connect{self.clear}
      }
      self.textChanged.connect{ |s| @clearButton.visible=(s.size>0)}
      frameWidth=self.style.pixelMetric(Qt::Style::PM_DefaultFrameWidth)
      padding=@clearButton.sizeHint.width+frameWidth+1
      self.styleSheet="padding-right: #{padding}px;"
      msz=self.minimumSizeHint
      self.minimumSize=Qt::Size.new(
        [msz.width,@clearButton.sizeHint.height+frameWidth*2+2].max,
        [msz.height,@clearButton.sizeHint.height+frameWidth*2+2].max)
      end
      
    def resizeEvent(event)
      super(event)
      if @clearButton
        sz=@clearButton.sizeHint
        frameWidth=self.style.pixelMetric(Qt::Style::PM_DefaultFrameWidth)
        @clearButton.move(rect.right-frameWidth-sz.width,
                          (rect.bottom+1-sz.height)/2)
      end
      if @placeholder
        sz=@placeholder.sizeHint
        @placeholder.move(2,2)
      end
    end

    def placeholderText=(s)
      @placeholder.text='' if @placeholder
      @placeholder=Qt::Label.new(self) { |p|
        p.styleSheet="color:grey;font:italic;"
        p.move(2,2)
        p.minimumWidth=self.width-4
        p.text=s
        p.visible=true
      }
    end
    def focusInEvent(e)
      @placeholder.visible=false if @placeholder
      super(e)
    end
    def focusOutEvent(e)
      @placeholder.visible=(text.size==0) if @placeholder
      super(e)
    end
    def text=(x)
      @placeholder.visible=((x.size==0) && !hasFocus) if @placeholder
      super(x)
    end
  end
end