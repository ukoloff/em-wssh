require 'fileutils'
require 'getoptlong'
require 'faye/websocket'

opts = GetoptLong.new(
  ['-l', '--listen', GetoptLong::REQUIRED_ARGUMENT],
  ['-d', '--daemon', GetoptLong::NO_ARGUMENT],
)

def help
  puts <<-EOF
connect - simple HTTP CONNECT proxy to WSSH daemon

Usage: #{File.basename __FILE__} [options...] ws[s]://host[:port]/uri

  -l --listen=port Listen to port
  -d --daemon      Run daemonized
  -h --help        Show this help
EOF
  exit 1
end

port = 3122
daemon = false

begin
  opts.each do |opt, arg|
    case opt
    when '-d'
      daemon=true
    when '-l'
      port=arg
    end
  end
rescue
  help
end

help if ARGV.length!=1

def log(*msg)
  msg.unshift "[#{Time.now}]"
  puts msg*' '
end

def daemonize
  throw 'Cannot daemonize on Windows!' if Gem.win_platform?

  log "Going on in background..."

  FileUtils.mkdir_p log=File.dirname(__FILE__)+'/log'
  log = File.open log+'/connect.log', 'a'
  log.sync=true

  STDIN.reopen '/dev/null'
  STDOUT.reopen log
  STDERR.reopen log

  Process.daemon true, true
end

daemonize if daemon

log "Running on port #{port}, sending to #{ARGV[0]}"

def pid
  FileUtils.mkdir_p pid=File.dirname(__FILE__)+'/tmp/pids'
  File.write pid+='/connect.pid', $$
  at_exit do
    log "Exiting..."
    File.unlink pid
  end
end

pid

module HttpConn
  def post_init
    port, ip = Socket.unpack_sockaddr_in(get_peername)
    log "Client connected from #{ip}:#{port}"
  end

  def wssh data
    @ws.send data.unpack 'C*' if data.length>0
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
    if (@nhdr+=1)>1
      connect_wssh if 0==line.length
    else
      parse line
    end
  end

  def connect_wssh
    @body = [@hdrs]
    @hdrs=''
    send_data "HTTP/1.0 200 Ok\r\n\r\n"

    log "Redirect to", uri="#{ARGV[0]}/#{@wssh}"
    @ws = Faye::WebSocket::Client.new uri

    @ws.on :open do |event|
      log "Connected to WSSHD"
      @body.each{|data|wssh data}
      @body=true
    end

    @ws.on :message do |event|
      send_data Array===event.data ? event.data.pack('C*') : event.data
    end

    @ws.on :close do
      log "Websocket closed"
      close_connection
    end
  end

  def parse line
    m=/^connect\s+([-.\w]+):22(?:$|\s)/i.match line
    return @wssh = m[1] if m
    send_data "HTTP/1.0 500 Bad request\r\n\r\n"
    close_connection
  end

  def unbind
    log "Client disconnected"
    @ws.close if @ws
  end
end

EM.run do
  EM.start_server "127.0.0.1", port, HttpConn
end
