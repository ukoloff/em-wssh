module Connect
  require_relative 'service'
  extend Service

  @options={
    host: 'localhost',
    port: 3122,
    daemon: false,
    root: File.dirname(__FILE__),
    log: 'log/connect.log',
    pid: 'tmp/pids/connect.pid',
  }

  def self.help
    puts <<-EOF
Simple HTTP CONNECT proxy to WSSH daemon

Usage: ruby #{File.basename __FILE__} [options...] ws[s]://host[:port]/uri

  -l --listen=port Listen to port
  -a --all         Listen to all interfaces
  -d --daemon      Run daemonized
  -h --help        Show this help
    EOF
    exit 1
  end

  def self.getopt
    opts = GetoptLong.new(
      ['-l', '--listen', GetoptLong::REQUIRED_ARGUMENT],
      ['-d', '--daemon', GetoptLong::NO_ARGUMENT],
      ['-a', '--all', GetoptLong::NO_ARGUMENT],
    )
    begin
      opts.each do |opt, arg|
        case opt
        when '-d'
          options[:daemon]=true
        when '-l'
          options[:port]=arg
        when '-a'
          options[:host]='0.0.0.0'
        end
      end
    rescue
      help
    end
    help if ARGV.length!=1
    options[:uri] = ARGV[0]
  end

  class Dst
    attr_accessor :http

    Connect=Module.nesting[1]

    def self.count
      @n||=0
      @n+=1
    end

    def initialize(http)
      self.http=http
      @count=self.class.count
    end

    def log *msg
      Connect.log "<#{@count}>", *msg
    end

    def send data
      @ws.send data.unpack 'C*' if data.length>0
    end

    def connect! host
      log "Redirect to", uri="#{Connect.options[:uri]}/#{host}"

      http.onbody

      @ws = Faye::WebSocket::Client.new uri

      @ws.on :open do |event| onopen end
      @ws.on :message do |event| onmessage event end
      @ws.on :close do |event| onclose end
      @ws.on :error do |error| onerror error end
    end

    def onopen
      log "Connected to WSSHD"
      http.onopen
    end

    def onmessage event
      http.send_data Array===event.data ? event.data.pack('C*') : event.data
    end

    def onerror error
      log "Websocket error", error
      bye
    end

    def onclose
      log "Websocket closed"
      bye
    end

    def bye
      http.close_connection if http
      @ws.close if @ws
      instance_variables.each{|v| remove_instance_variable v if '@count'!=v.to_s}
    end
  end

  module Http
    attr_accessor :dst

    def log *msg
      dst.log *msg
    end

    def wssh data
      dst.send data
    end

    def post_init
      self.dst = Dst.new self

      port, ip = Socket.unpack_sockaddr_in get_peername
      log "Client connected from", "#{ip}:#{port}"
    end

    def receive_data data
      if @body
        if Array===@body
          @body << data
        else
          wssh data
        end
        return
      end

      if @hdrs
        @hdrs << data
      else
        @hdrs = data
      end
      while m=/\r?\n/.match(@hdrs)
        @hdrs=m.post_match
        receive_line m.pre_match
      end
    end

    def receive_line line
      @nhdr||=0
      if 1==(@nhdr+=1)
        m=/^connect\s+([-.\w]+):22(?:$|\s)/i.match line
        return @wssh = m[1] if m
        @hdrs=''
        log "Bad request"
        send_data "HTTP/1.0 500 Bad request\r\n\r\n"
        dst.bye
      else
        dst.connect! @wssh if 0==line.length
      end
    end

    def onbody
      @body=[@hdrs]
      @hdrs=''
      send_data "HTTP/1.0 200 Ok\r\n\r\n"
    end

    def onopen
      @body.each{|data| wssh data}
      @body=true
    end

    def unbind
      log "Client disconnected"
      dst.bye
    end
  end

  def self.listen!
    EM.start_server options[:host], options[:port], Http
  end

  def self.loop
    require 'faye/websocket'
    EM.run{ listen! }
  end

  go!

end
