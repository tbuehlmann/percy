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
    user = Percy.is_online(match[1])
    if user
      Percy.message env[:channel], "#{user} is online!"
    else
      Percy.message env[:channel], "#{user} is not online!"
    end
  end
end

Percy.connect
