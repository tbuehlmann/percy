class PercyLogger
  require 'thread'
  
  DEBUG   = 0
  INFO    = 1
  WARN    = 2
  ERROR   = 3
  FATAL   = 4
  UNKNOWN = 5
  LEVEL   = ['DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL', 'UNKNOWN']
  
  attr_accessor :level, :time_format, :file
  
  def initialize(filename = 'log.log', level = DEBUG, time_format = '%d.%m.%Y %H:%M:%S')
    @filename = filename
    @level = level
    @time_format = time_format
    @mutex = Mutex.new
    
    unless File.exist?(@filename)
      unless File.directory?(File.dirname(@filename))
        Dir.mkdir(File.dirname(@filename))
      end
      File.new(@filename, 'w+')
    end
    
    @file = File.open(@filename, 'a+')
    @file.sync = true
  end
  
  def write(severity, message)
    begin
      if severity >= @level
        @mutex.synchronize do
          @file.puts "#{LEVEL[severity]} #{Time.now.strftime(@time_format)} #{message}"
        end
      end
    rescue => e
      puts e.message
      puts e.backtrace.join('\n')
    end
  end
  
  def debug(message)
    write DEBUG, message
  end
  
  def info(message)
    write INFO, message
  end
  
  def warn(message)
    write WARN, message
  end
  
  def error(message)
    write ERROR, message
  end
  
  def fatal(message)
    write FATAL, message
  end
  
  def unknown(message)
    write UNKNOWN, message
  end
end
