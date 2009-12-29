$:.unshift File.expand_path(File.dirname(__FILE__))

require 'rubygems'
require 'eventmachine'
require 'percylogger'
require 'timeout'
require 'thread'

Thread.abort_on_exception = true

class Connection < EventMachine::Connection
  include EventMachine::Protocols::LineText2
  
  def connection_completed
    Percy.raw "NICK #{Percy.config.nick}"
    Percy.raw "USER #{Percy.config.nick} 0 * :#{Percy.config.username}"
    Percy.raw "PASS #{Percy.config.password}" if Percy.config.password
  end
  
  def unbind
    Percy.connected = false
    Percy.traffic_logger.info('-- Percy disconnected') if Percy.traffic_logger
    puts "#{Time.now.strftime('%d.%m.%Y %H:%M:%S')} -- Percy disconnected"
    if Percy.config.reconnect
      Percy.traffic_logger.info("-- Reconnecting in #{Percy.config.reconnect_interval} seconds") if Percy.traffic_logger
      puts "#{Time.now.strftime('%d.%m.%Y %H:%M:%S')} -- Reconnecting in #{Percy.config.reconnect_interval} seconds"
      
      EventMachine::add_timer(Percy.config.reconnect_interval) do
        reconnect Percy.config.server, Percy.config.port
      end
    end
  end
  
  def receive_line(line)
    Percy.parse line
  end
end

class Percy
  class << self
    attr_reader :config
    attr_accessor :traffic_logger, :connected
  end
  
  VERSION = 'Percy 1.1.0 (http://github.com/tbuehlmann/percy)'
  
  Config = Struct.new(:server, :port, :password, :nick, :username, :verbose, :logging, :reconnect, :reconnect_interval)
  
  @config = Config.new("localhost", 6667, nil, 'Percy', 'Percy', true, false, false, 30)
  
  # helper variables for getting server return values
  @observers = 0
  @temp_socket = []
  
  @connected = false
  
  # user methods
  @events = Hash.new []
  @listened_types = [:connect, :channel, :query, :join, :part, :quit, :nickchange, :kick] # + 3-digit numbers
  
  # observer synchronizer
  @mutex_observer = Mutex.new
  
  def self.configure(&block)
    block.call(@config)
    
    # logger
    @traffic_logger = PercyLogger.new("#{PERCY_ROOT}/logs/traffic.log") if @config.logging
    @error_logger = PercyLogger.new("#{PERCY_ROOT}/logs/error.log") if @config.logging
  end
  
  # raw IRC messages
  def self.raw(message)
    @connection.send_data "#{message}\r\n"
    @traffic_logger.info(">> #{message}") if @traffic_logger
    puts "#{Time.now.strftime('%d.%m.%Y %H:%M:%S')} >> #{message}" if @config.verbose
  end
  
  # send a message
  def self.message(recipient, message)
    self.raw "PRIVMSG #{recipient} :#{message}"
  end
  
  # send a notice
  def self.notice(recipient, message)
    self.raw "NOTICE #{recipient} :#{message}"
  end
  
  # set a mode
  def self.mode(recipient, option)
    self.raw "MODE #{recipient} #{option}"
  end
  
  # kick a user
  def self.kick(channel, user, reason)
    if reason
      self.raw "KICK #{channel} #{user} :#{reason}"
    else
      self.raw "KICK #{channel} #{user}"
    end
  end
  
  # perform an action
  def self.action(recipient, message)
    self.raw "PRIVMSG #{recipient} :\001ACTION #{message}\001"
  end
  
  # set a topic
  def self.topic(channel, topic)
    self.raw "TOPIC #{channel} :#{topic}"
  end
  
  # joining a channel
  def self.join(channel, password = nil)
    if password
      self.raw "JOIN #{channel} #{password}"
    else
      self.raw "JOIN #{channel}"
    end
  end
  
  # parting a channel
  def self.part(channel, message)
    if msg
      self.raw "PART #{channel} :#{message}"
    else
      self.raw 'PART'
    end
  end
  
  # quitting
  def self.quit(message = nil)
    if message
      self.raw "QUIT :#{message}"
    else
      self.raw 'QUIT'
    end
    
    @config.reconnect = false # so Percy does not reconnect after the socket has been closed
  end
  
  def self.nick
    @config.nick
  end
  
  # returns all users on a specific channel
  def self.users_on(channel)
    self.add_observer
    self.raw "NAMES #{channel}"
    
    begin
      Timeout::timeout(10) do # try 10 seconds to retrieve the users of <channel>
        start = 0
        ending = @temp_socket.length
        
        loop do
          for line in start..ending do
            if @temp_socket[line] =~ /^:\S+ 353 \S+ = #{channel} :/
              return $'.split(' ')
            end
          end
          
          sleep 0.25
          start = ending
          ending = @temp_socket.length
        end
      end
    rescue Timeout::Error
      return false
    ensure
      self.remove_observer
    end
  end
  
  # get the channel limit of a channel
  def self.channel_limit(channel)
    self.add_observer
    self.raw "MODE #{channel}"
    
    begin
      Timeout::timeout(10) do # try 10 seconds to retrieve l mode of <channel>
        start = 0
        ending = @temp_socket.length
        
        loop do
          for line in start..ending do
            if @temp_socket[line] =~ /^:\S+ 324 \S+ #{channel} .*l.* (\d+)/
              return $1.to_i
            end
          end
          
          sleep 0.25
          start = ending
          ending = @temp_socket.length
        end
      end
    rescue Timeout::Error
      return false
    ensure
      self.remove_observer
    end
  end
  
  # check whether an user is online
  def self.is_online(nick)
    self.add_observer
    self.raw "WHOIS #{nick}"
    
    begin
      Timeout::timeout(10) do
        start = 0
        ending = @temp_socket.length
        
        loop do
          for line in start..ending do
            if @temp_socket[line] =~ /^:\S+ 311 \S+ (#{nick}) /i
              return $1
            elsif line =~ /^:\S+ 401 \S+ #{nick} /i
              return false
            end
          end
          
          sleep 0.25
          start = ending
          ending = @temp_socket.length
        end
      end
    rescue Timeout::Error
      return false
    ensure
      self.remove_observer
    end
  end
  
  # on method
  def self.on(type = :channel, match = //, &block)
    unless @listened_types.include?(type) || type =~ /^\d\d\d$/
      raise ArgumentError, "#{type} is not a supported type"
    end
    
    @events[type] = [] if @events[type].empty? # @events' default value is [], but it's not possible to add elements to it (weird!)
    case type
    when :channel || :query
      @events[type] << {:match => match, :proc => block}
    else
      @events[type] << block
    end
  end
  
  # add observer
  def self.add_observer
    @mutex_observer.synchronize do
      @observers += 1
    end
  end
  
  # remove observer
  def self.remove_observer
    @mutex_observer.synchronize do
      @observers -= 1 # remove observer
      @temp_socket = [] if @observers == 0 # clear @temp_socket if no observers are active
    end
  end
  
  # parses incoming traffic (types)
  def self.parse_type(type, env = nil)
    case type
    when /^\d\d\d$/
      if @events[type]
        @events[type].each do |block|
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
      # :connect
      if type =~ /^376|422$/
        @events[:connect].each do |block|
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
      end
    
    when :channel
      @events[type].each do |method|
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
        self.notice env[:nick], "\001VERSION #{VERSION}\001"
      end
      
      # time response
      if env[:message] == "\001TIME\001"
        self.notice env[:nick], "\001TIME #{Time.now.strftime('%a %b %d %H:%M:%S %Y')}\001"
      end
      
      # ping response
      if env[:message] =~ /\001PING (\d+)\001/
        self.notice env[:nick], "\001PING #{$1}\001"
      end
      
      @events[type].each do |method|
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
      @events[type].each do |block|
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
      @events[type].each do |block|
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
      @events[type].each do |block|
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
      @events[type].each do |block|
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
      @events[type].each do |block|
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
  
  # connect!
  def self.connect
    @traffic_logger.info('-- Starting Percy') if @traffic_logger
    puts "#{Time.now.strftime('%d.%m.%Y %H:%M:%S')} -- Starting Percy"
    
    EventMachine::run do
      @connection = EventMachine::connect(@config.server, @config.port, Connection)
    end
  end
  
  # parsing incoming traffic
  def self.parse(message)
    @traffic_logger.info("<< #{message.chomp}") if @traffic_logger
    puts "#{Time.now.strftime('%d.%m.%Y %H:%M:%S')} << #{message.chomp}" if @config.verbose
    
    case message.chomp
    when /^PING \S+$/
      self.raw message.chomp.gsub('PING', 'PONG')
    
    when /^:\S+ (\d\d\d) /
      self.parse_type($1, :params => $')
    
    when /^:(\S+)!(\S+)@(\S+) PRIVMSG #(\S+) :/
      self.parse_type(:channel, :nick => $1, :user => $2, :host => $3, :channel => "##{$4}", :message => $')
    
    when /^:(\S+)!(\S+)@(\S+) PRIVMSG \S+ :/
      self.parse_type(:query, :nick => $1, :user => $2, :host => $3, :message => $')
    
    when /^:(\S+)!(\S+)@(\S+) JOIN :*(\S+)$/
      self.parse_type(:join, :nick => $1, :user => $2, :host => $3, :channel => $4)
    
    when /^:(\S+)!(\S+)@(\S+) PART (\S+)/
      self.parse_type(:part, :nick => $1, :user => $2, :host => $3, :channel => $4, :message => $'.sub(' :', ''))
    
    when /^:(\S+)!(\S+)@(\S+) QUIT/
      self.parse_type(:quit, :nick => $1, :user => $2, :host => $3, :message => $'.sub(' :', ''))
    
    when /^:(\S+)!(\S+)@(\S+) NICK :/
      self.parse_type(:nickchange, :nick => $1, :user => $2, :host => $3, :new_nick => $')
    
    when /^:(\S+)!(\S+)@(\S+) KICK (\S+) (\S+) :/
      self.parse_type(:kick, :nick => $1, :user => $2, :host => $3, :channel => $4, :victim => $5, :reason => $')
    end
    
    if @observers > 0
      @temp_socket << message.chomp
    end
  end
end
