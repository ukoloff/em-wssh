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
  end

  def receive_data data
    ws.send data
  end

  def unbind
    log 'SSH server closed connection'
    ws.close
  end
end

def resolve(path)
  path = path.to_s
  .split(/[^-.\w]+/)
  .select{|s|s.length>0}
  .select{|s|!s.match /^[-_.]|[-_.]$/}
  .last
  yml = YAML.load_file File.dirname(__FILE__)+'/hosts.yml'

  if yml.key? path
    host = yml[path]
    raise 'X' unless host
    host = path if true===host
    host = host.to_s.strip
    raise 'X' if 0==host.length
    return host
  end

  host=nil

  yml.each do |k, v|
    next unless m=/^\/(.*)\/(i?)$/.match(k)
    next unless Regexp.new(m[1], m[2]).match path
    raise 'X' unless v
    host = true===v ? path : v
    host = host.to_s.strip
    raise 'X' if 0==host.length
  end
  raise 'X' unless host
  host
end

EM.run do
  EM::WebSocket.run host: "0.0.0.0", port: port do |ws|

    client = nil
    buf = []

    ws.onopen do |handshake|
      log "Request", handshake.path
      unless host = resolve(handshake.path) rescue nil
        log "Invalid host"
        ws.close
        next
      end
      log "Connecting to", host
      EM.connect host, 22, Ssh do |conn|
        client = conn
        client.ws = ws
        buf.each{|data| client.send_data buf}
        buf = nil
      end
    end

    ws.onbinary do |msg|
      if buf
        buf.push msg
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
