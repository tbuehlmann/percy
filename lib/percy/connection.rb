require 'rubygems'
require 'eventmachine'

module Percy
  class Connection < EventMachine::Connection
    include EventMachine::Protocols::LineText2
    
    def connection_completed
      IRC.raw "NICK #{IRC.config.nick}"
      IRC.raw "USER #{IRC.config.nick} 0 * :#{IRC.config.username}"
      IRC.raw "PASS #{IRC.config.password}" if IRC.config.password
    end
    
    def unbind
      IRC.connected = false
      IRC.traffic_logger.info('-- Percy disconnected') if IRC.traffic_logger
      puts "#{Time.now.strftime('%d.%m.%Y %H:%M:%S')} -- Percy disconnected"
      
      if IRC.config.reconnect
        IRC.traffic_logger.info("-- Reconnecting in #{IRC.config.reconnect_interval} seconds") if IRC.traffic_logger
        puts "#{Time.now.strftime('%d.%m.%Y %H:%M:%S')} -- Reconnecting in #{IRC.config.reconnect_interval} seconds"
        
        EventMachine::add_timer(IRC.config.reconnect_interval) do
          reconnect IRC.config.server, IRC.config.port
        end
      else
        EventMachine::stop_event_loop
      end
    end
    
    def receive_line(line)
      IRC.parse line
    end
  end
end
