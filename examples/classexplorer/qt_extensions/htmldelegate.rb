#
#Itemdelegate allowing the use of html-formatted items
#use stylesheets for special formatting of tagged text (see defaultdoc)
#provide external Qt::TextDocument (HtmlDelegat#doc=) for more flexibility

module QtExtensions
  class HtmlDelegate < Qt::ItemDelegate
    attr_accessor :doc
    
    def paint(painter, option, index)
      drawBackground(painter,option,index)
      @doc||= defaultdoc
      item=index.model.data(index).toString
      if (option.state.value & Qt::Style::State_Selected.value) !=0
        item=%Q[<span class="selected">#{item}</span>]
      end

      @doc.setHtml(item)
      painter.save
      painter.translate(option.rect.topLeft)
      r=Qt::RectF.new(0,0,option.rect.width,option.rect.height)
      @doc.drawContents(painter,r)
      painter.restore
    end
    
    def defaultdoc
      return Qt::TextDocument.new { |d|
        d.defaultStyleSheet=%Q[.hilite {background-color: yellow;color:black; }
        .selected {color: white}
        .special {color: goldenrod}
        ]}
    end
    
    def sizeHint(option,index)
      @doc||=defaultdoc
      @doc.setHtml(index.model.data(index).toString)
      return @doc.size.toSize
    end
  end
end  