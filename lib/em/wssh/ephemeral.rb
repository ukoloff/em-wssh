require_relative 'service'

module EventMachine::Wssh
class Ephemeral
  extend Service

  @options={
    base: '.',
    pid: 'tmp/pids/ephemeral.pid',
    log: 'log/ephemeral.log',
  }

  %i(log options mkdir).each do |meth|
    define_method meth do |*args|
      self.class.send meth, *args
    end
  end

  def initialize
    require 'socket'
    @sock=Addrinfo.tcp('127.0.0.1', 0).listen 1
  end

  def myport
    Socket.unpack_sockaddr_in(@sock.getsockname).first
  end

  def rport
    sock=@sock.accept.first
    at_exit{sock}
    sock.gets.to_i
  end

  def allocate uri
    log "Running WSSH proxy..."
    spawn *%w(bundle exec wssh ephemeral), myport.to_s, uri,
      %i(out err)=>File.open(mkdir(:log), 'a')

    rport
  end

  def self.allocate uri
    new.allocate uri
  end

  def self.help
    require_relative 'exe'
    puts <<-EOF
Run HTTP proxy on ephemeral port

#{Exe.usage} <port> <uri>

For internal use.
    EOF
    exit
  end

  def self.go!
    help if 2!=ARGV.length
    require_relative 'connect'

    pid

    Connect.options.merge!(
      port: 0,
      uri: ARGV[1],
      ping: 50,
      onlisten: Proc.new{|port| onlisten port},
    )
    Connect.loop!
  end

  module Parent
    def initialize port
      @port=port
      @c=EM::Wssh::Connect
      log "Listening to port", port
    end

    def log *args
      @c.log *args
    end

    def post_init
      log "Connected to parent"
      send_data "#{@port}\n"
    end

    def unbind
      log "Parent disconnected"
      EM.stop_event_loop
    end
  end

  def self.onlisten port
    EM.connect 'localhost', ARGV[0], Parent, port
  end

end
end
