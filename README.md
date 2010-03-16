# Percy 1.4.0

## Installing Percy
`sudo gem install percy`

## Configuring and starting the bot

### mybot.rb
    require 'rubygems'
    require 'percy'
    
    configure do |c|
      c.server             = 'chat.eu.freenode.net'
      c.port               = 6667
      # c.password         = 'password'
      c.nick               = 'Percyguy'
      c.username           = 'Percyguy'
      c.verbose            = true
      c.logging            = true
      c.reconnect          = true
      c.reconnect_interval = 30
    end
    
    connect

Start it with `ruby mybot.rb`.

## Handling Events

You can also call all methods with `Percy::IRC`, like `Percy::IRC.join('#that_cool_channel')`.

### Connect
    on :connect do
      # ...
    end
No variables.

### Channel message
    on :channel, /^foo!/ do |env|
      # ...
    end
Variables:

<tt>env[:nick]<br />
env[:user]<br />
env[:host]<br />
env[:channel]<br />
env[:message]</tt>

### Query message
    on :query, /^bar!/ do |env|
      # ...
    end
Variables:

<tt>env[:nick]<br />
env[:user]<br />
env[:host]<br />
env[:message]</tt>

### Join
    on :join do |env|
      # ...
    end
Variables:

<tt>env[:nick]<br />
env[:user]<br />
env[:host]<br />
env[:channel]</tt>

### Part
    on :part do |env|
      # ...
    end
Variables:

<tt>env[:nick]<br />
env[:user]<br />
env[:host]<br />
env[:channel]<br />
env[:message]</tt>

### Quit
    on :quit do |env|
      # ...
    end
Variables:

<tt>env[:nick]<br />
env[:user]<br />
env[:host]<br />
env[:message]</tt>

### Nickchange
    on :nickchange do |env|
      # ...
    end
Variables:

<tt>env[:nick]<br />
env[:user]<br />
env[:host]<br />
env[:new_nick]</tt>

### Kick
    on :kick do |env|
      # ...
    end
Variables:

<tt>env[:nick]<br />
env[:user]<br />
env[:host]<br />
env[:channel]<br />
env[:victim]<br />
env[:reason]</tt>

### Raw Numerics
    on '301' do |env|
      # ...
    end
Variables:

<tt>env[:params]</tt>

## Availabe Class Methods

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

## Formatting

There are constants for formatting your messages. They are all availabe through `Percy::Formatting` or by including the module.

Availabe formatting constants:

`PLAIN`  
`BOLD`  
`ITALIC`  
`UNDERLINE`  
`COLOR_CODE`  
`UNCOLOR`  
`COLORS`

Availabe colors through the `COLORS` hash:

`:white`  
`:black`  
`:blue`  
`:green`  
`:red`  
`:brown`  
`:purple`  
`:orange`  
`:yellow`  
`:lime`  
`:teal`  
`:cyan`  
`:royal`  
`:pink`  
`:gray`  
`:silver`

### Example:
    message '#that_cool_channel',
            "#{Percy::Formatting::COLOR_CODE}#{Percy::Formatting::COLORS[:red]}This is red text.#{Percy::Formatting::UNCOLOR} This is not."

### Example with included Percy::Formatting module:
    message '#that_cool_channel',
            "#{COLOR_CODE}#{COLORS[:red]}This is red text.#{UNCOLOR} This is not."

## License
Copyright (c) 2009, 2010 Tobias Bühlmann

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
