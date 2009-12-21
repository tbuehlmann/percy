$:.unshift "#{File.expand_path(File.dirname(__FILE__))}/lib"
PERCY_ROOT = File.expand_path(File.dirname(__FILE__))

require 'rubygems'
require 'percy'

Percy.configure do |c|
  c.server    = 'chat.eu.freenode.net'
  c.port      = 6667
  c.nick      = 'Percy_onlchk'
  c.verbose   = true
  c.logging   = false
  c.reconnect = false
end

Percy.on :connect do
  Percy.join '#that_cool_channel'
end

Percy.on :channel, /^!quit$/ do
  Percy.quit
end

Percy.on :channel, /^online\?/ do |env|
  match = env[:message].split(' ')
  if match.length > 1
    nick = Percy.is_online(match[1])
    if nick
      Percy.message env[:channel], "#{nick} is online!"
    else
      Percy.message env[:channel], "#{nick} is not online!"
    end
  end
end

Percy.connect
