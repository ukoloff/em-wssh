require_relative 'uri'

module EventMachine::Wssh
module Client

  Title='Connect to WSSH server'

  Need=%w(faye/websocket)

  def self.help
    require_relative 'exe'
    puts <<-EOT
WSSH client

#{Exe.usage} ws[s]://host[:port]/uri
    EOT
    exit 1
  end

  def self.getopt
    help if ARGV.length!=1
    @uri=ARGV[0]
  end

  class Stdio
    Chunk=0x10000

    def initialize srv
      @srv=srv
      @t=Thread.new{loop}
    end

    def loop
      begin
        until STDIN.eof
          @srv.send STDIN.readpartial Chunk
        end
      rescue=>e
      ensure
        EM.stop
      end
    end

    def bye
      @t.exit
    end
  end

  class Ws
    def initialize uri
      @ws=Faye::WebSocket::Client.new uri

      @ws.on :open do |event| onopen end
      @ws.on :message do |event| onmessage event.data end
      @ws.on :close do |event| onclose end
      @ws.on :error do |error| onerror error end
    end

    def send data
      @ws.send data.unpack 'C*'
    end

    def onopen
      @stdio=Stdio.new self
    end

    def onmessage data
      STDOUT << data.pack('C*')
    end

    def onclose
      bye
    end

    def onerror error
      bye
    end

    def bye
      @stdio.bye if @stdio
      @ws.close if @ws
      @ws=nil
      EM.stop
    end
  end

  def self.listen!
    TLS.mute!
    Ws.new TLS.wrap @uri
  end

  def self.loop!
    self::Need.each{|f| require f}
    EM.run{ listen! }
  end

  def self.go!
    getopt
    STDOUT.sync=true
    STDIN.binmode
    STDOUT.binmode
    loop!
  end
end
end
