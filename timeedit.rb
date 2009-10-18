#!/usr/bin/ruby

require 'open-uri'
require 'rubygems'
require 'icalendar'
require 'sinatra'

include Icalendar

# ToDo
# parametrar för att filtrera FÖ, LE, LA osv

helpers do
  def code_to_id(code)
    url = "http://timeedit.liu.se/4DACTION/WebShowSearch/5/1-0?wv_search=#{code}"
    content = ""
    open(url) {|s| content = s.read}
    return content.match(/addObject\((\d+)\)/).to_a[1]
  end
  
  def timeedit(code)
    id = code_to_id(code)
    url = "http://timeedit.liu.se/4DACTION/iCal_downloadReservations/timeedit.ics?id1=#{id}&branch=5&lang=0"
    content = "" # raw content of ical feed will be loaded here
    open(url) {|s| content = s.read }
  
    cals = Icalendar.parse(content)
    cal = cals.first
  
    newcal = Calendar.new
    newcal.custom_property("X-WR-CALNAME", "LiU")
  
    cal.events.each do |event|
        m = event.summary.match(/(\w+), (\S+),/).to_a
        kurskod = m[1]
        typ = m[2]
        plats = event.location
        if plats != nil
          if plats[-1].chr == "_"
            plats = event.location[0..-2] 
          end
        end
        if typ != nil
          if typ[0].chr == "F"
            typ = "FÖ"
          end
        end
        if typ != nil and plats != nil
          sum = "#{kurskod} #{typ} i #{plats}"
          newcal.event do
            dtstart(event.start)
            dtend(event.end)
            summary(sum)
            location(event.location)
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
end

get '/' do
  "Just append the course code to the base URL of this page, and enjoy the iCal data."
end

get '/:code' do
  content_type "text/calendar"
  if valid(params[:code])
    timeedit(params[:code])
  else
    "Sorry, your code doesn't cut it."
  end
end