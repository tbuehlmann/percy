$:.unshift "#{File.expand_path(File.dirname(__FILE__))}/lib"
PERCY_ROOT = File.expand_path(File.dirname(__FILE__))

require 'rubygems'
require 'percy'

bot = Percy.new

bot.configure do |c|
  c.server = 'chat.eu.freenode.net'
  c.port = 6667
  c.nick = 'Percy_onlchk'
  c.verbose = true
  c.logging = false
end

bot.on :connect do
  bot.join '#that_cool_channel'
end

bot.on :channel, /^!quit$/ do
  bot.quit
end

bot.on :channel, /^online\?/ do |env|
  match = env[:message].split(' ')
  if match.length > 1
    nick = bot.is_online(match[1])
    if nick
      bot.message env[:channel], "#{nick} is online!"
    else
      bot.message env[:channel], "#{nick} is not online!"
    end
  end
end

bot.connect
