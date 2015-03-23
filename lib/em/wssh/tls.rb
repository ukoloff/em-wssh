require 'socket'
require 'openssl'
require 'openssl/win/root' if Gem.win_platform?

require_relative 'service'

module EventMachine::Wssh
class TLS
  extend Service

  Chunk=0x10000

  def self.run! host
    @@host=host
    s=TCPServer.new '127.0.0.1', 0
    log "WSTunnel on #{s.addr} -> #{host}"
    Thread.new do
      new s.accept while true
    end
    s.addr[1]
  end

  def self.count
    @n||=0
    @n+=1
  end

  def initialize client
    @count=self.class.count
    @client=client
    @t1=Thread.new{cloop!}
  end

  def log *msg
    self.class.log "<&#{@count}>", *msg
  end

  def cloop!
    begin
      log "Connected from", @client.peeraddr
      cloop
    rescue=>e
      log "Client error", e
    ensure
      log "Client disconnected"
      @client.close
      @t2.exit if @t2
    end
  end

  def headerz
    r=[]
    until @client.eof
      s=@client.gets.strip
      break if 0==s.length
      r << s
    end
    r
  end

  def headerz! headers
    return headers if headers.length<1
    verb=headers.shift
    [verb]+
    %w(Host Origin).map{|h| "#{h}: #{@@host}"}+
    headers.reject{|h| /^(?:host|origin):/i.match h}
  end

  def connect!
    srv=Socket.tcp @@host, 443
    ctx=OpenSSL::SSL::SSLContext.new
    ctx.set_params verify_mode: OpenSSL::SSL::VERIFY_PEER
    srv=OpenSSL::SSL::SSLSocket.new srv, ctx
    srv.hostname=@@host if srv.respond_to? :hostname=
    srv.connect
    srv
  end

  def cloop
    h=headerz! headerz
    if h.length<1
      @client.write "HTTP/1.0 500 Invalid request\r\n"
      return
    end
    @headers=h
    @server=connect!
    @t2=Thread.new{sloop!}
    @server.write @client.readpartial Chunk until @client.eof
  end

  def sloop!
    begin
      log "Connected to server;", "Verify=#{@server.verify_result}"
      sloop
    rescue=>e
      log "Server error", e
    ensure
      log "Server disconnected"
      @server.close
      @t1.exit
    end
  end

  def sloop
    @server.write @headers*"\r\n"+"\r\n"*2
    @headers=nil
    @client.write @server.readpartial Chunk until @server.eof
  end
end
end
