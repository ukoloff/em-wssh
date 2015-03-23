require 'Socket'
require 'openssl'
require 'openssl/win/root' if Gem.win_platform?

require_relative '../wssh'

module EventMachine::Wssh
class TLS
  Host='ya.ru'

  Chunk=0x10000

  def self.run!
    puts "WSTunnel is listening..."
    Socket.tcp_server_loop 'localhost', 8082 do |client, addr|
      puts "Connected from #{addr.ip_address}:#{addr.ip_port}"
      new client
    end
  end

  def initialize client
    @host=Host
    @client=client
    @t1=Thread.new{cloop!}
  end

  def cloop!
    begin
      puts "<Client>"
      cloop
    rescue=>e
      puts "Client error: #{e}"
    ensure
      puts "</Client>"
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
    %w(Host Origin).map{|h| "#{h}: #{@host}"}+
    headers.reject{|h| /^(?:host|origin):/i.match h}
  end

  def connect!
    srv=Socket.tcp @host, 443
    ctx=OpenSSL::SSL::SSLContext.new
    ctx.set_params verify_mode: OpenSSL::SSL::VERIFY_PEER
    srv=OpenSSL::SSL::SSLSocket.new srv, ctx
    srv.hostname=@host if srv.respond_to? :hostname=
    srv.connect
    puts "Connected to server; #{srv.verify_result}"
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
      puts "<Server>"
      sloop
    rescue=>e
      puts "Server error: #{e}"
    ensure
      puts "</Server>"
      @server.close
      @t1.exit
    end
  end

  def sloop
    @server.write @headers*"\r\n"+"\r\n"*2
    @headers=nil
    @client.write @server.readpartial Chunk until @server.eof
  end

  run!
end
end
