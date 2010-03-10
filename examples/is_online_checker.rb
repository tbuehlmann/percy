require 'rubygems'
require 'percy'

Percy::IRC.configure do |c|
  c.server    = 'chat.eu.freenode.net'
  c.port      = 6667
  c.nick      = 'Percy_onlchk'
  c.verbose   = true
  c.logging   = false
  c.reconnect = false
end

Percy::IRC.on :connect do
  Percy::IRC.join '#that_cool_channel'
end

Percy::IRC.on :channel, /^!quit$/ do
  Percy::IRC.quit
end

Percy::IRC.on :channel, /^online\?/ do |env|
  match = env[:message].split(' ')
  if match.length > 1
    user = Percy::IRC.is_online(match[1])
    if user
      Percy::IRC.message env[:channel], "#{user} is online!"
    else
      Percy::IRC.message env[:channel], "#{user} is not online!"
    end
  end
end

Percy::IRC.connect
