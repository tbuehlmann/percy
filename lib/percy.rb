require 'pathname'
$:.unshift Pathname.new(__FILE__).dirname.expand_path
require 'percy/irc'
require 'percy/formatting'
Thread.abort_on_exception = true

module Percy
  VERSION = 'Percy 1.4.1 (http://github.com/tbuehlmann/percy)'
  
  # set the percy root directory
  Object::const_set(:PERCY_ROOT, Pathname.new($0).dirname.expand_path)
end

def delegate(*methods)
  methods.each do |method|
   eval <<-EOS
      def #{method}(*args, &block)
        Percy::IRC.send(#{method.inspect}, *args, &block)
      end
    EOS
  end
end

delegate :action, :channel_limit, :configure, :connect, :is_online, :join, :kick, :message,
         :mode, :nick, :notice, :on, :part, :quit, :raw, :topic, :users_on, :users_with_status_on,
         :reload
