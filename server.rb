require 'yaml'
require 'getoptlong'
require 'em-websocket'

opts = GetoptLong.new(
  ['-l', '--listen', GetoptLong::REQUIRED_ARGUMENT],
  ['-d', '--daemon', GetoptLong::NO_ARGUMENT],
)

def help
  puts <<-EOF
wssh - proxy ssh thru websocket

Usage: #{File.basename __FILE__} [options...]

  -l --listen=port Listen to port
  -d --daemon      Run daemonized
  -h --help        Show this help
EOF
  exit 1
end

port = 4567
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

def log(*msg)
  msg.unshift "[#{Time.now}]"
  puts msg*' '
end

log "Running d=#{daemon} on port #{port}"

module Ssh
  attr_accessor :ws, :buf

  def post_init
    log "Connected to SSH server"
    # buf.each{|data| send_data buf}
    self.buf=nil
  end

  def receive_data data
    log "From SSH"
    ws.send data
  end

  def unbind
    log 'SSH server closed connection'
    ws.close
  end
end

EM.run do
  EM::WebSocket.run host: "0.0.0.0", port: port do |ws|

    client = nil

    ws.onopen do |handshake|
      log "Request", handshake.path
      EM.connect 'github.com', 22, Ssh do |conn|
        log "+++"
        client = conn
        client.ws = ws
        # client.buf = []
      end
    end

    ws.onbinary do |msg|
      log "From WS"
      if client.buf
        client.buf.push msg
      else
        client.send_data msg
      end
    end

    ws.onclose do
      log 'Client closed connection'
      client.close_connection if client
    end

    ws.onerror do |err|
      log "Error...", err
      client.close_connection if client
    end
  end
end
