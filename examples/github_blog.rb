require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'percy'

# abbreviated notation without Percy::IRC
configure do |c|
  c.server    = 'chat.eu.freenode.net'
  c.port      = 6667
  c.nick      = 'Percy_ghblog'
  c.verbose   = true
  c.logging   = false
  c.reconnect = false
end

on :connect do
  join 'that_cool_channel'
end

on :channel, /^!quit$/ do
  quit
end

on :channel, /^blog\?$/ do |env|
  doc = Nokogiri::HTML(open('http://github.com/blog'))
  title = doc.xpath('//html/body/div/div[2]/div/div/ul/li/h2/a')[0].text
  
  message env[:channel], "Newest Github Blog Post: #{title}"
end

connect
