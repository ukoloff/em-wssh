require_relative '../wssh'

module EventMachine::Wssh
module Client

  Title='Connect to WSSH server'

  Need=%w(faye/websocket)

  def self.help
    require_relative 'exe'
    puts <<-EOT
WSSH client

Usage: #{Exe.biname} ws[s]://host[:port]/uri
    EOT
    exit 1
  end

  def self.getopt
    help if ARGV.length!=1
    @uri=ARGV[0]
  end

  class Ws
    def initialize uri
      @buf=[]

      @ws=Faye::WebSocket::Client.new uri

      @ws.on :open do |event| onopen end
      @ws.on :message do |event| onmessage event.data end
      @ws.on :close do |event| onclose end
      @ws.on :error do |error| onerror error end
    end

    def queue data
      if @buf
        @buf << data
      else
        @ws.send data
      end
    end

    def onopen
      @buf.each{|data| @ws.send data}
      @buf=nil
    end

    def onmessage data
      print data.pack 'C*'
    end

    def onclose
      bye
    end

    def onerror error
      bye
    end

    def bye
      @ws.close if @ws
      @ws=nil
      @buf=nil
      EM.stop_event_loop
    end
  end

  module Stdio
    def initialize ws
      @ws = ws
    end

    def receive_data data
      @ws.queue data.unpack 'C*'
    end

    def unbind
      @ws.bye
    end
  end

  def self.listen!
    EM.attach $stdin, Stdio, Ws.new(@uri)
  end

  def self.loop!
    self::Need.each{|f| require f}
    EM.run{ listen! }
  end

  def self.go!
    getopt
    STDOUT.sync=true
    loop!
  end
end
end
