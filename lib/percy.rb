$:.unshift File.expand_path(File.dirname(__FILE__))

require 'percylogger'
require 'socket'
require 'timeout'
require 'thread'

Thread.abort_on_exception = true

class Percy
  VERSION = 'Percy 0.0.4 (http://github.com/tbuehlmann/percy)'
  
  Config = Struct.new(:server, :port, :password, :nick, :username, :verbose, :logging)
  
  def initialize
    @config = Config.new("localhost", 6667, nil, 'Percy', 'Percy', true, false)
    
    # helper variables for getting server return values
    @observers = 0
    @temp_socket = []
    
    # user methods
    @on_channel    = []
    @on_query      = []
    @on_connect    = []
    @on_join       = []
    @on_part       = []
    @on_quit       = []
    @on_nickchange = []
    @on_kick       = []
    
    # observer synchronizer
    @mutex = Mutex.new
    
    # running variable (provisional solution for rejoining at netsplit)
    @running = true
  end
  
  # configure block
  def configure(&block)
    block.call(@config)
    
    # logger
    @traffic_logger = PercyLogger.new("#{PERCY_ROOT}/logs/traffic.log") if @config.logging
    @error_logger = PercyLogger.new("#{PERCY_ROOT}/logs/error.log") if @config.logging
  end
  
  # raw irc messages
  def raw(msg)
    @socket.puts "#{msg}\r\n"
    @traffic_logger.info(">> #{msg}") if @traffic_logger
    puts "#{Time.now.strftime('%d.%m.%Y %H:%M:%S')} >> #{msg}" if @config.verbose
  end
  
  # send a message
  def message(recipient, msg)
    raw "PRIVMSG #{recipient} :#{msg}"
  end
  
  # send a notice
  def notice(recipient, msg)
    raw "NOTICE #{recipient} :#{msg}"
  end
  
  # set a mode
  def mode(recipient, option)
    raw "MODE #{recipient} #{option}"
  end
  
  # get the channellimit of a channel
  def channellimit(channel)
    add_observer
    raw "MODE #{channel}"
    
    begin
      Timeout::timeout(10) do # try 10 seconds to retrieve l mode of <channel>
        loop do
          @temp_socket.each do |line|
            if line =~ /^:(\S+) 324 (\S+) #{channel} .*l.* (\d+)/
              return $3.to_i
            end
          end
          sleep 0.5
        end
      end
    rescue Timeout::Error
      return false
    ensure
      remove_observer
    end
  end
  
  # check whether an user is online
  def is_online(nick)
    add_observer
    raw "WHOIS #{nick}"
    
    begin
      Timeout::timeout(10) do
        loop do
          @temp_socket.each do |line|
            if line =~ /^:(\S+) 311 (\S+) (#{nick}) /i
              return $3
            elsif line =~ /^:\S+ 401 \S+ #{nick} /i
              return false
            end
          end
          sleep 0.5
        end
      end
    rescue Timeout::Error
      return false
    ensure
      remove_observer
    end
  end
  
  # kick a user
  def kick(channel, user, reason)
    if reason
      raw "KICK #{channel} #{user} :#{reason}"
    else
      raw "KICK #{channel} #{user}"
    end
  end
  
  # perform an action
  def action(recipient, msg)
    raw "PRIVMSG #{recipient} :\001ACTION #{msg}\001"
  end
  
  # set a topic
  def topic(channel, topic)
    raw "TOPIC #{channel} :#{topic}"
  end
  
  # joining a channel
  def join(channel, password = nil)
    if password
      raw "JOIN #{channel} #{password}"
    else
      raw "JOIN #{channel}"
    end
  end
  
  # parting a channel
  def part(channel, msg)
    if msg
      raw "PART #{channel} :#{msg}"
    else
      raw 'PART'
    end
  end
  
  # quitting
  def quit(msg = nil)
    if msg
      raw "QUIT :#{msg}"
    else
      raw 'QUIT'
    end
    
    @running = false # so Percy does not reconnect after the socket has been closed
  end
  
  # on method
  def on(type = :channel, match = //, &block)
    case type
      when :channel
        @on_channel << {:match => match, :proc => block}
      when :connect
        @on_connect << block
      when :query
        @on_query << {:match => match, :proc => block}
      when :join
        @on_join << block
      when :part
        @on_part << block
      when :quit
        @on_quit << block
      when :nickchange
        @on_nickchange << block
      when :kick
        @on_kick << block
    end
  end
  
  # add observer
  def add_observer
    @mutex.synchronize do
      @observers += 1
    end
  end
  
  # remove observer
  def remove_observer
    @mutex.synchronize do
      @observers -= 1 # remove observer
      @temp_socket = [] if @observers == 0 # clear @temp_socket if no observers are active
    end
  end
  
  # returns all users on a specific channel
  def users_on(channel)
    add_observer
    raw "NAMES #{channel}"
    
    begin
      Timeout::timeout(10) do # try 10 seconds to retrieve the users of <channel>
        loop do
          @temp_socket.each do |line|
            if line =~ /^:(\S+) 353 (\S+) = #{channel} :/
              return $'.split(' ')
            end
          end
          sleep 0.5
        end
      end
    rescue Timeout::Error
      return false
    ensure
      remove_observer
    end
  end
  
  # parses incoming traffic
  def parse(type, env = nil)
    case type
    when :connect
      @on_connect.each do |block|
        Thread.new do
          begin
            unless @connected
              @connected = true
              block.call
            end
          rescue => e
              if @error_logger
                @error_logger.error(e.message)              
                e.backtrace.each do |line|
                  @error_logger.error(line)
                end
              end
          end
        end
      end
    
    when :channel
      @on_channel.each do |method|
        if env[:message] =~ method[:match]
          Thread.new do
            begin
              method[:proc].call(env)
            rescue => e
              if @error_logger
                @error_logger.error(e.message)              
                e.backtrace.each do |line|
                  @error_logger.error(line)
                end
              end
            end
          end
        end
      end
    
    when :query
      # version respones
      if env[:message] == "\001VERSION\001"
        notice env[:nick], "\001VERSION #{VERSION}\001"
      end
      
      # time response
      if env[:message] == "\001TIME\001"
        notice env[:nick], "\001TIME #{Time.now.strftime('%a %b %d %H:%M:%S %Y')}\001"
      end
      
      # ping response
      if env[:message] =~ /\001PING (\d+)\001/
        notice env[:nick], "\001PING #{$1}\001"
      end
      
      @on_query.each do |method|
        if env[:message] =~ method[:match]
          Thread.new do
            begin
              method[:proc].call(env)
            rescue => e
              if @error_logger
                @error_logger.error(e.message)              
                e.backtrace.each do |line|
                  @error_logger.error(line)
                end
              end
            end
          end
        end
      end
    
    when :join
      @on_join.each do |block|
        Thread.new do
          begin
            block.call(env)
          rescue => e
            if @error_logger
              @error_logger.error(e.message)              
              e.backtrace.each do |line|
                @error_logger.error(line)
              end
            end
          end
        end
      end
    
    when :part
      @on_part.each do |block|
        Thread.new do
          begin
            block.call(env)
          rescue => e
            if @error_logger
              @error_logger.error(e.message)              
              e.backtrace.each do |line|
                @error_logger.error(line)
              end
            end
          end
        end
      end
    
    when :quit
      @on_quit.each do |block|
        Thread.new do
          begin
            block.call(env)
          rescue => e
            if @error_logger
              @error_logger.error(e.message)              
              e.backtrace.each do |line|
                @error_logger.error(line)
              end
            end
          end
        end
      end
    
    when :nickchange
      @on_nickchange.each do |block|
        Thread.new do
          begin
            block.call(env)
          rescue => e
            if @error_logger
              @error_logger.error(e.message)              
              e.backtrace.each do |line|
                @error_logger.error(line)
              end
            end
          end
        end
      end
    
    when :kick
      @on_kick.each do |block|
        Thread.new do
          begin
            block.call(env)
          rescue => e
            if @error_logger
              @error_logger.error(e.message)              
              e.backtrace.each do |line|
                @error_logger.error(line)
              end
            end
          end
        end
      end
    end
  end
  
  def nick
    @config.nick
  end
  
  # connect!
  def connect
    begin
      while @running
        @traffic_logger.info('-- Starting Percy') if @traffic_logger
        puts "#{Time.now.strftime('%d.%m.%Y %H:%M:%S')} -- Starting Percy"
        
        
        @socket = TCPSocket.open(@config.server, @config.port)
        raw "PASS #{@config.password}" if @config.password
        raw "NICK #{@config.nick}"
        raw "USER #{@config.nick} 0 * :#{@config.username}"
        
        while line = @socket.gets
          @traffic_logger.info("<< #{line.chomp}") if @traffic_logger
          puts "#{Time.now.strftime('%d.%m.%Y %H:%M:%S')} << #{line.chomp}" if @config.verbose
          
          case line.chomp
          when /^PING \S+$/
            raw line.chomp.gsub('PING', 'PONG')
          
          when /^:(\S+) (376|422)/
            parse(:connect)
          
          when /^:(\S+)!(\S+)@(\S+) PRIVMSG #(\S+) :/
            parse(:channel, :nick => $1, :user => $2, :host => $3, :channel => "##{$4}", :message => $')
          
          when /^:(\S+)!(\S+)@(\S+) PRIVMSG (\S+) :/
            parse(:query, :nick => $1, :user => $2, :host => $3, :message => $')
          
          when /^:(\S+)!(\S+)@(\S+) JOIN :*(\S+)$/
            parse(:join, :nick => $1, :user => $2, :host => $3, :channel => $4)
          
          when /^:(\S+)!(\S+)@(\S+) PART (\S+)/
            parse(:part, :nick => $1, :user => $2, :host => $3, :channel => $4, :message => $'.sub(' :', ''))
          
          when /^:(\S+)!(\S+)@(\S+) QUIT/
            parse(:quit, :nick => $1, :user => $2, :host => $3, :message => $'.sub(' :', ''))
          
          when /^:(\S+)!(\S+)@(\S+) NICK :/
            parse(:nickchange, :nick => $1, :user => $2, :host => $3, :new_nick => $')
          
          when /^:(\S+)!(\S+)@(\S+) KICK (\S+) (\S+) :/
            parse(:kick, :nick => $1, :user => $2, :host => $3, :channel => $4, :victim => $5, :reason => $')
          end
          
          if @observers > 0
            @temp_socket << line.chomp
          end
        end
        
        @traffic_logger.info('-- Percy disconnected') if @traffic_logger
        puts "#{Time.now.strftime('%d.%m.%Y %H:%M:%S')} -- Percy disconnected"
        @connected = false
      end
    rescue => e
      @error_logger.error(e.message)              
      e.backtrace.each do |line|
        @error_logger.error(line)
      end
      
      @traffic_logger.info('-- Percy disconnected') if @traffic_logger
      puts "#{Time.now.strftime('%d.%m.%Y %H:%M:%S')} -- Percy disconnected"
      @connected = false
    ensure
      @traffic_logger.file.close if @traffic_logger
      @error_logger.file.close if @error_logger
    end
  end
end
