#!/usr/bin/ruby

require 'open-uri'
require 'rubygems'
require 'icalendar'
require 'sinatra'
require 'erb'
include Icalendar

DEBUG = false

helpers do
  def to_id(str)
    if str.match(/^\w{4}\d{2}$/)
      return code_to_id(str)
    else
      return group_to_id(str)
    end
  end
  
  def group_to_id(group)
    # This function may only support groups where you have to choose a sub-group
    subgroup = group[-1].chr.downcase
    group = group[0..-2] if group.length > 2
    url = "http://timeedit.liu.se/4DACTION/WebShowSearch/5/1-0?wv_type=8&wv_search=#{group}"
    content = ""
    open(url) {|s| content = s.read}
    if content =~ (/<OPTION value='(\d+)'>#{subgroup}<\/OPTION>/)
      id = $1
    elsif content =~ (/addObject\((\d+)\)/)
      id = $1
    end
    return id
  end
  
  def code_to_id(code)
    url = "http://timeedit.liu.se/4DACTION/WebShowSearch/5/1-0?wv_search=#{code}"
    content = ""
    open(url) {|s| content = s.read}
    return content.match(/addObject\((\d+)\)/).to_a[1]
  end
  
  def timeedit(codes, filterstr = "only", types_to_filter = "ALL", exclude = false)
    types_to_filter = types_to_filter.split(",")
    # works for both course and group
    url = "http://timeedit.liu.se/4DACTION/iCal_downloadReservations/timeedit.ics?branch=5&#{id_str(codes,:ical)}lang=1"
    content = "" # raw content of ical feed will be loaded here
    open(url) {|s| content = s.read }
  
    cals = Icalendar.parse(content)
    cal = cals.first

    newcal = Calendar.new
    newcal.custom_property("X-WR-CALNAME;VALUE=TEXT", "#{codes}")
    newcal.custom_property("X-WR-CALDESC;VALUE=TEXT", "schedule for #{codes}")
  
    cal.events.each do |event|
      # Summary can contain two course codes like
      #  "TDDC73, TDDD13, F\303\226, C2, IT2, Anders Fr\303\266berg, Johan \303\205berg"
      # or just one
      #  "TDDC73, LA, C2, Johan Jernl\303\245s"

      # 2011-03-19
      #  TimeEdit now uses "Lektion" instead of LE and so on
      event.summary = translate_long_type_to_short_type(event.summary)

      m = event.summary.match(/(\w{4}\d{2}, \w{4}\d{2}), (\S+),|(\w{4}\d{2}), (\S+),/).to_a.reject{|item| item==nil}

      code = m[1] || event.summary.split(",")[0]
      typ = m[2] || "NOTYPE"
      typ = "FO" if typ[0].chr == "F"
      plats = event.location

      # Stitch things togheter
      if typ != nil and plats != nil
        new_summary = "#{event.summary} (#{plats})"
        event.summary(new_summary)
        if filterstr == "only"
          types_to_filter.each do |type|
            if type == typ || type == "ALL"
              if exclude && exclude.include?(code)
                # do not add event
              else
                newcal.add_event(event)
              end
            end
          end
        elsif filterstr == "no"
          if types_to_filter.include?(typ) || exclude && exclude.include?(code)
            # do not add event
          else
            newcal.add_event(event)
          end
        end
      end
    end
    return newcal.to_ical
  end
  
  def render_ical(*args)
    if DEBUG
      "<pre>#{timeedit(*args)}</pre>"
    else
      content_type "text/calendar"
      timeedit(*args)
    end
  end
  
  def valid(input)
    # Is it a course code?
    if input.match(/^\w{4}\d{2}$/)
      return true
    # It might be a group
    else
      if group_to_id(input) == nil
        return false
      else      
        return true
      end
    end
  end
  
  def valid_input(list)
    list.split(",").each do |input|
      return valid(input)
    end
  end
  
  def id_str(codes, type)
    str = ""
    codes.split(",").each_with_index do |code,i|
      if type == :gfx
        str += "wv_obj#{i+1}=#{to_id(code)}&"
      elsif type == :ical
        str += "id#{i+1}=#{to_id(code)}&"
      end
    end
    return str
  end 
  
  # PR	  	Projektarbete
  # LE	  	Lektion
  # LA	  	Laboration
  # SE	  	Seminarium
  # RE	  	Redovisning
  # GU	  	Gruppundervisning
  def translate_long_type_to_short_type(summary)
    types = { "Projektarbete"     => "PR",
              "Lektion"           => "LE",
              "Laboration"        => "LA",
              "Seminarium"        => "SE",
              "Redovisning"       => "RE",
              "Gruppundervisning" => "GU" }
    types.each do |type_long, type_short|
      if summary.include?(type_long)
        summary = summary.gsub(type_long, type_short)
      end
    end
    return summary
  end

  def valid_types(types)
    valid_types = %w(FO LE LA GU SE PR RE)
    types.split(",").each do |type|
      return false if not valid_types.include?(type)
    end
    return true
  end

  def valid_filter(str)
    str == "only" || str == "no"
  end
end

get '/' do
  erb :index
end

get '/:codes' do
  if valid_input(params[:codes])
    @url = "http://timeedit.liu.se/4DACTION/WebShowSearch/5/1-0?wv_type=6&#{id_str(params[:codes], :gfx)}wv_graphic=Grafiskt+format"
    erb :gfx   
  else
    @error = "Sorry, one of your codes does not cut it."
    erb :index
  end
end

get '/:codes/ical' do
  if valid_input(params[:codes])
    render_ical(params[:codes])
  else
    @error = "Sorry, one of your codes does not cut it."
  end
end

get '/:codes/:filter/:types' do
  # /TDDC73/only/FO,LE
  if valid_input(params[:codes]) && valid_filter(params[:filter]) && valid_types(params[:types])
    render_ical(params[:codes], params[:filter], params[:types])
  # /Y3A/exclude/TDTS08,TATA26
  elsif valid_input(params[:codes]) && params[:filter] == "exclude" && valid_input(params[:types])
    render_ical(params[:codes], "only", "ALL", params[:types])
  else
    @error = "You are doing it wrong."
    erb :index
  end
end

get '/:codes/:filter/:types/exclude/:exclude_codes' do
  if valid_input(params[:codes]) && valid_filter(params[:filter]) && valid_types(params[:types]) && valid_input(params[:exclude_codes])
    render_ical(params[:codes], params[:filter], params[:types], params[:exclude_codes])
  else
    @error = "You are doing it wrong."
    erb :index
  end
end

not_found do
  @error = "Not found!"
  erb :index
end