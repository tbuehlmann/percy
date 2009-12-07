# Percy 0.0.5

## Configuring and starting the bot

### mybot.rb
    $:.unshift "#{File.expand_path(File.dirname(__FILE__))}/lib"
    PERCY_ROOT = File.expand_path(File.dirname(__FILE__))

    require 'rubygems'
    require 'percy'
    
    bot = Percy.new
    
    bot.configure do |c|
      c.server = 'chat.eu.freenode.net'
      c.port = 6667
      c.nick = 'Percyguy'
      c.verbose = true
      c.logging = true
    end
    
    bot.connect

Start it with `ruby mybot.rb`.

## Handling Events
### Connect
    bot.on :connect do
      # ...
    end
No variables.

### Channel message
    bot.on :channel, /^foo!/ do |env|
      # ...
    end
Variables:

<tt>env[:nick]
env[:user]
env[:host]
env[:channel]
env[:message]</tt>

### Query message
    bot.on :query, /^bar!/ do |env|
      # ...
    end
Variables:

<tt>env[:nick]
env[:user]
env[:host]
env[:message]</tt>

### Join
    bot.on :join do |env|
      # ...
    end
Variables:

<tt>env[:nick]
env[:user]
env[:host]
env[:channel]</tt>

### Part
    bot.on :part do |env|
      # ...
    end
Variables:

<tt>env[:nick]
env[:user]
env[:host]
env[:channel]
env[:message]</tt>

### Quit
    bot.on :quit do |env|
      # ...
    end
Variables:

<tt>env[:nick]
env[:user]
env[:host]
env[:message]</tt>

### Nickchange
    bot.on :nickchange do |env|
      # ...
    end
Variables:

<tt>env[:nick]
env[:user]
env[:host]
env[:new_nick]</tt>

### Kick
    bot.on :kick do |env|
      # ...
    end
Variables:

<tt>env[:nick]
env[:user]
env[:host]
env[:channel]
env[:victim]
env[:reason]</tt>

## Availabe Methods

`raw(msg)`

Sends a raw message to the server.

`message(recipient, msg)`

Sends a message to a channel or an user.

`notice(recipient, msg)`

Sends a notice to an user.

`action(recipient, msg)`

Performs an action (/me ...).

`mode(recipient, option)`

Sets a mode for a channel or an user.

`channellimit(channel)`

Returns the channel limit of a channel (as integer if set, else (not set/timeout) false).

`kick(channel, user, reason)`

Kicks an user from a channel with a specific reason.

`topic(channel, topic)`

Sets the topic for a channel.

`join(channel, password = nil)`

Joins a channel.

`part(channel, msg)`

Parts a channel with a message.

`quit(msg = nil)`

Quits from the server with a message.

`users_on(channel)`

Returns an array of users from a channel (mode in front like: ['@percy', 'Peter_Parker', '+The_Librarian']) or false if timeout.


`is_online(nick)`

Returns a nickname as string if online, else false (not online/timeout)

## License
Copyright (c) 2009 Tobias Bühlmann

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
