# This is for including in models
# because accessing the standard rails view helper methods is difficult
# Taken and adapted from rails/actionpack/lib/action_view/helpers/text_helper.rb
#

module TextileToHtml
  AUTO_LINK_RE = /(<\w+.*?>|[^=!:'"\/]|^)((?:http[s]?:\/\/)|(?:www\.))(([\w~]+:?[=?&\/.-]?)*\w+[\/]?(?:\#\w*)?)([[:punct:]]|\s|<|$)/x
             
  def textile_to_html(textile)
    if not textile.nil?
      html = RedCloth.new( textile, [:filter_html] ).to_html(:textile)
      html = auto_link_urls( html )
      html = escape_javascript_links( html )
      return html
    else
      return nil
    end
  end
  
  private 
  
  def escape_javascript_links( html )
    html.gsub(/(href=['"])\s*javascript:.*?(['"][ >])/, '\1\2')
  end
  
  def auto_link_urls(text)
    text.gsub(AUTO_LINK_RE) do
      all, a, b, c, d = $&, $1, $2, $3, $5
      if a =~ /<a\s/i # don't replace URL's that are already linked
        all
      else
        %(#{a}<a href="#{b=="www."?"http://www.":b}#{c}">#{b + c}</a>#{d})
      end
    end
  end
end
