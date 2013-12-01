require "wikilize/version"

module Wikilize
  
  require "stringio"
  require "strscan"
  require "uri"
  
  begin
    require "syntax/convertors/html"
  rescue LoadError
  end
  class << self
    #この用な形式のwikiitemを返す
    # { 
    #   [
    #     main_menu: "経歴",
    #     contents:  "すごい経歴をもっている"
    #     sub_menus:
    #       [
    #         {sub_menu: "中学校", contents: "馬鹿だった"},
    #         {sub_menu: "高校", contents: "天才だった"}
    #       ]
    #   ],…
    # }
    def extracter(text)
      markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, space_after_headers: true, fenced_code_blocks: true)
      html = markdown.render(text)
      main_menus = Nokogiri::HTML(html).css("h2").map(&:inner_text) rescue []
      begin
        contents = Wikilize.extract_from_tag(html,"h2")
        sub_menus_ary = contents.map do |content|
          sub_menus = Nokogiri::HTML(content).css("h3").map(&:inner_text)
          sub_menu_contents = Wikilize.extract_from_tag(content, "h3")
          returner = {main_contents: content.split(/\<h3\>/).first, sub_menus: []}
          sub_menus.each.with_index(0) do |sub_menu,i|
            h = {
              sub_menu:     sub_menu, 
              sub_contents: sub_menu_contents[i]
            }
            returner[:sub_menus] << h
          end
          returner
        end
      rescue
        sub_menus_ary = []
      end
      result = []
      main_menus.each.with_index(0) do |main_menu,i|
        h = {
          main_menu:     main_menu, 
          main_contents: sub_menus_ary[i][:main_contents],
          sub_menus:     sub_menus_ary[i][:sub_menus]
        }
       result << h
      end
      result
    end

    def extract_from_tag(html, tag)
      contents = html.scan(/\<\/#{tag}\>.+?\<#{tag}\>/m).map do |scan|
        str = scan.gsub(/\<#{tag}\>/,"")
        str = str.gsub(/\<\/#{tag}\>/,"")
      end
      contents <<  html.split(/\<\/#{tag}\>.+?/m).last
    end

    def extract_biography(text)
      begin
        text.scan(/\|.+/).map do |item|
          f_item = item.split(/\=/).map(&:strip)
          {label: f_item.first.delete("|"), contents: f_item.last}
        end
      rescue
        []
      end
    end

    def extract_title(text)
      text = text.encode("UTF-16BE", "UTF-8", invalid: :replace, undef: :replace, replace: '.').encode("UTF-8")
      str = HikiDoc.to_html(text)
      #str.split("<h2 class='agenda'>").select{|str| str.include?("</h2>")}
      #Regexp.new("<h2 class='agenda'>.+</h2>");
      item = Hash.new([])
      
      item[:doc] = HikiDoc.to_html(text)
      /{{Infobox.+?Infobox}}/m =~ item[:doc]
      item[:doc] = item[:doc].sub($&,'') rescue item[:doc]
      ($&.try(:scan,(/¥|\w.*/))||[]).each do |x|
        if text.include?("=")
          y = Hash.new([])
          y[:key] = x.split(/ = /)[0]
          y[:value] = x.split(/ = /)[1]
          item[:detail] << y
        end
      end

      item[:menu_texts] = []
      while m = /(?-mix:<h2 class='agenda'>.+<\/h2>)/i.match(str)
        str = m.post_match
        item[:menu_texts] << m.to_s
      end
      return item
    end
  end
end