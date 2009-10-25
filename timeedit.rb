#!/usr/bin/ruby

require 'open-uri'
require 'rubygems'
require 'icalendar'
require 'sinatra'
require 'erb'
include Icalendar

helpers do
  def code_to_id(code)
    url = "http://timeedit.liu.se/4DACTION/WebShowSearch/5/1-0?wv_search=#{code}"
    content = ""
    open(url) {|s| content = s.read}
    return content.match(/addObject\((\d+)\)/).to_a[1]
  end
  
  def timeedit(codes, filterstr = "only", types = "ALL")
    types = types.split(",")
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
      m = event.summary.match(/(\w{4}\d{2}, \w{4}\d{2}), (\S+),|(\w{4}\d{2}), (\S+),/).to_a.reject{|item| item==nil}
      code = m[1]
      typ = m[2]
      typ = "FO" if typ[0].chr == "F"
      plats = event.location
      
      # Stitch things togheter
      if typ != nil and plats != nil
        if filterstr == "only"
          types.each do |type|
            if type == typ || type == "ALL"
              event.summary("#{code} #{typ} i #{plats}")
              newcal.add_event(event)
            end
          end
        elsif filterstr == "no"
          types.each do |type|
            if type != typ
              event.summary("#{code} #{typ} i #{plats}")
              newcal.add_event(event)
            end
          end
        end
      end
    end
    return newcal.to_ical
  end
  
  def valid(code)
    if code.match(/^\w{4}\d{2}$/)
      return true
    else
      false
    end
  end
  
  def valid_codes(codes)
    codes.split(",").each do |code|
      if not valid(code)
        return false
      end
    end
  end
  
  def id_str(codes, type)
    str = ""
    codes.split(",").each_with_index do |code,i|
      if type == :gfx
        str += "wv_obj#{i+1}=#{code_to_id(code)}&"
      elsif type == :ical
        str += "id#{i+1}=#{code_to_id(code)}&"
      end
    end
    return str
  end
  
  def valid_types(types)
    types = %w(FO, LE, LA, LE, GU, SE)
    types.each do |type|
      return false if not types.include?(type)
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
  if valid_codes(params[:codes])
    @url = "http://timeedit.liu.se/4DACTION/WebShowSearch/5/1-0?wv_type=6&#{id_str(params[:codes], :gfx)}wv_graphic=Grafiskt+format"
    erb :gfx
  else
    @error = "Sorry, one of your codes does not cut it."
    erb :index
  end
end

get '/:codes/ical' do
  if valid_codes(params[:codes])
    # DEBUG
    # "<pre>#{timeedit(params[:codes])}</pre>"
    content_type "text/calendar"
    timeedit(params[:codes])
  else
    @error = "Sorry, one of your codes does not cut it."
  end
end

get '/:codes/:filter/:types' do
  if valid_codes(params[:codes]) && valid_filter(params[:filter]) && valid_types(params[:types])
    # DEBUG
    # "<pre>#{timeedit(params[:codes], params[:filter], params[:types])}</pre>"
    content_type "text/calendar"
    timeedit(params[:codes], params[:filter], params[:types])
  else
    @error = "You are doing it wrong."
    erb :index
  end
end

not_found do
  @error = "Not found!"
  erb :index
end