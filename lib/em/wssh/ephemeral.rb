require_relative 'service'

module EventMachine::Wssh
module Ephemeral
  extend Service

  @options={
    base: '.',
    proxy: 'log/ephemeral.log',
    tls: 'log/tls.log',
  }

  class Accept
    def initialize
      require 'socket'
      @sock=Addrinfo.tcp('127.0.0.1', 0).listen 1
    end

    def myport
      Socket.unpack_sockaddr_in(@sock.getsockname).first
    end

    def port
      sock=@sock.accept.first
      at_exit{sock}
      sock.gets.to_i
    end
  end

  def self.allocate uri
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

    Connect.options.merge!(
      port: 0,
      onlisten: Proc.new{|port| onlisten port}
    )
    Connect.loop!
  end

  def onlisten port
  end

end
end
