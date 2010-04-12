require 'ostruct'
require 'timeout'
require 'thread'
require 'percy/connection'
Percy.autoload :'PercyLogger', 'percy/percylogger'

module Percy
  class IRC
    class << self
      attr_reader :config
      attr_accessor :traffic_logger, :connected
    end
    
    @config = OpenStruct.new({:server             => 'localhost',
                              :port               => 6667,
                              :nick               => 'Percy',
                              :username           => 'Percy',
                              :verbose            => true,
                              :logging            => false,
                              :reconnect          => true,
                              :reconnect_interval => 30})
    
    # helper variables for getting server return values
    @observers = 0
    @temp_socket = []
    
    @connected = false
    @reloading = false
    
    # user methods
    @events = Hash.new []
    @listened_types = [:connect, :channel, :query, :join, :part, :quit, :nickchange, :kick] # + 3-digit numbers
    
    # observer synchronizer
    @mutex_observer = Mutex.new
    
    def self.configure(&block)
      unless @reloading
        block.call(@config)
        
        # logger
        if @config.logging
          @traffic_logger = PercyLogger.new(Pathname.new(PERCY_ROOT).join('logs').expand_path, 'traffic.log')
          @error_logger   = PercyLogger.new(Pathname.new(PERCY_ROOT).join('logs').expand_path, 'error.log')
        end
      end
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
    
    # returns all users on a specific channel as array: ['Foo', 'bar', 'The_Librarian']
    def self.users_on(channel)
      actual_length = self.add_observer
      self.raw "NAMES #{channel}"
      channel = Regexp.escape(channel)
      
      begin
        Timeout::timeout(30) do # try 30 seconds to retrieve the users of <channel>
          start = actual_length
          ending = @temp_socket.length
          users = []
          
          loop do
            for line in start..ending do
              case @temp_socket[line]
              when /^:\S+ 353 .+ #{channel} :/i
                users << $'.split(' ')
              when /^:\S+ 366 .+ #{channel}/i
                return users.flatten.uniq.map { |element| element.gsub(/[!@%+]/, '') } # removing all modes
              end
            end
            
            sleep 0.25
            start = ending
            ending = @temp_socket.length
          end
        end
      rescue Timeout::Error
        return []
      ensure
        self.remove_observer
      end
    end
    
    # returns all users on a specific channel as array (with status): ['@Foo', '+bar', 'The_Librarian', '!Frank']
    def self.users_with_status_on(channel)
      actual_length = self.add_observer
      self.raw "NAMES #{channel}"
      channel = Regexp.escape(channel)
      
      begin
        Timeout::timeout(30) do # try 30 seconds to retrieve the users of <channel>
          start = actual_length
          ending = @temp_socket.length
          users = []
          
          loop do
            for line in start..ending do
              case @temp_socket[line]
              when /^:\S+ 353 .+ #{channel} :/i
                users << $'.split(' ')
              when /^:\S+ 366 .+ #{channel}/i
                return users.flatten.uniq
              end
            end
            
            sleep 0.25
            start = ending
            ending = @temp_socket.length
          end
        end
      rescue Timeout::Error
        return []
      ensure
        self.remove_observer
      end
    end
    
    # get the channel limit of a channel
    def self.channel_limit(channel)
      actual_length = self.add_observer
      self.raw "MODE #{channel}"
      
      begin
        Timeout::timeout(10) do # try 10 seconds to retrieve l mode of <channel>
          start = actual_length
          ending = @temp_socket.length
          channel = Regexp.escape(channel)
          
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
      actual_length = self.add_observer
      self.raw "WHOIS #{nick}"
      
      begin
        Timeout::timeout(10) do
          start = actual_length
          ending = @temp_socket.length
          nick = Regexp.escape(nick)
          
          loop do
            for line in start..ending do
              if @temp_socket[line] =~ /^:\S+ 311 \S+ (#{nick}) /i
                return $1
              elsif @temp_socket[line] =~ /^:\S+ 401 \S+ #{nick} /i
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
    def self.on(type = [:channel], match = //, &block)
      if (type.is_a?(Symbol) || type.is_a?(String))
        type = [type.to_sym]
      end
      
      if type.is_a? Array
        type.each do |t|
          unless @listened_types.include?(t) || t =~ /^\d\d\d$/
            raise ArgumentError, "#{t} is not a supported type"
          end
          
          if @events[t].empty?
            @events[t] = [] # @events' default value is [], but it's not possible to add elements to it (weird!)
          end
          
          if (t == :channel || t == :query)
            @events[t] << {:match => match, :proc => block}
          else
            @events[t] << block
          end
        end
      end
    end
    
    # connect!
    def self.connect
      unless @reloading
        @traffic_logger.info('-- Starting Percy') if @traffic_logger
        puts "#{Time.now.strftime('%d.%m.%Y %H:%M:%S')} -- Starting Percy"
        
        EventMachine::run do
          @connection = EventMachine::connect(@config.server, @config.port, Connection)
        end
      end
    end
    
    def self.reload
      @reloading = true
      @events = Hash.new []
      load $0
      @reloading = false
    end
    
    def self.reloading?
      @reloading
    end
    
    private
    
    # add observer
    def self.add_observer
      @mutex_observer.synchronize do
        @observers += 1
      end
      
      return @temp_socket.length - 1 # so the loop knows where to begin to search for patterns
    end
    
    # remove observer
    def self.remove_observer
      @mutex_observer.synchronize do
        @observers -= 1 # remove observer
        @temp_socket.clear if @observers == 0 # clear @temp_socket if no observers are active
      end
    end
    
    # calls events with its begin; rescue; end
    def self.call_events(type, env)
      @events[type].each do |event|
        Thread.new do
          begin
            if type == :channel || type == :query
                event[:proc].call(env) if env[:message] =~ event[:match]
            else
              event.call(env)
            end
          rescue => e
            @error_logger.error(e.message, *e.backtrace) if @error_logger
          end
        end
      end
    end
    
    # parses incoming traffic (types)
    def self.parse_type(type, env = nil)
      case type
      # :connect
      when /^376|422$/
        unless @connected
          @connected = true
          self.call_events(:connect, env)
        end
      when :query
        # version response
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
        self.call_events(type, env)
      else
        self.call_events(type, env)
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
        self.parse_type($1, :type => $1.to_sym, :params => $')
      
      when /^:(\S+)!(\S+)@(\S+) PRIVMSG #(\S+) :/
        self.parse_type(:channel, :type => :channel, :nick => $1, :user => $2, :host => $3, :channel => "##{$4}", :message => $')
      
      when /^:(\S+)!(\S+)@(\S+) PRIVMSG \S+ :/
        self.parse_type(:query, :type => :query, :nick => $1, :user => $2, :host => $3, :message => $')
      
      when /^:(\S+)!(\S+)@(\S+) JOIN :*(\S+)$/
        self.parse_type(:join, :type => :join, :nick => $1, :user => $2, :host => $3, :channel => $4)
      
      when /^:(\S+)!(\S+)@(\S+) PART (\S+)/
        self.parse_type(:part, :type => :part, :nick => $1, :user => $2, :host => $3, :channel => $4, :message => $'.sub(' :', ''))
      
      when /^:(\S+)!(\S+)@(\S+) QUIT/
        self.parse_type(:quit, :type => :quit, :nick => $1, :user => $2, :host => $3, :message => $'.sub(' :', ''))
      
      when /^:(\S+)!(\S+)@(\S+) NICK :/
        self.parse_type(:nickchange, :type => :nickchange, :nick => $1, :user => $2, :host => $3, :new_nick => $')
      
      when /^:(\S+)!(\S+)@(\S+) KICK (\S+) (\S+) :/
        self.parse_type(:kick, :type => :kick, :nick => $1, :user => $2, :host => $3, :channel => $4, :victim => $5, :reason => $')
      end
      
      if @observers > 0
        @temp_socket << message.chomp
      end
    end
  end
end


