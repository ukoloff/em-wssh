require 'yaml'
require 'fileutils'
require 'em-websocket'

module Server
  @options={
    port: 4567,
    daemon: false,
  }

  def self.options
    @options
  end

  def self.log *msg
    msg.unshift "[#{Time.now}]"
    puts msg*' '
  end

  def self.help
    puts <<-EOF
wssh - proxy ssh thru websocket

Usage: #{File.basename __FILE__} [options...]

  -l --listen=port Listen to port
  -d --daemon      Run daemonized
  -h --help        Show this help
EOF
    exit 1
  end

  def self.getopt
    require 'getoptlong'

    opts = GetoptLong.new(
      ['-l', '--listen', GetoptLong::REQUIRED_ARGUMENT],
      ['-d', '--daemon', GetoptLong::NO_ARGUMENT],
    )
    begin
      opts.each do |opt, arg|
        case opt
        when '-d'
          options[:daemon]=true
        when '-l'
          options[:port]=arg
        end
      end
    rescue
      help
    end
    help unless ARGV.empty?
  end

  def self.daemonize!
    throw 'Cannot daemonize on Windows!' if Gem.win_platform?

    log "Going on in background..."

    FileUtils.mkdir_p log=File.dirname(__FILE__)+'/log'
    log = File.open log+'/wsshd.log', 'a'
    log.sync=true

    STDIN.reopen '/dev/null'
    STDOUT.reopen log
    STDERR.reopen log

    Process.daemon true, true
  end

  def self.daemonize?
    daemonize! if options[:daemon]
  end

  def self.pid
    FileUtils.mkdir_p pid=File.dirname(__FILE__)+'/tmp/pids'
    File.write pid+='/wsshd.pid', $$
    at_exit do
      log "Exiting..."
      File.unlink pid
    end
  end

  def self.go
    getopt
    daemonize?
    log "Running on port #{options[:port]}"
    pid
    EM.run do
      EM::WebSocket.run host: "0.0.0.0", port: options[:port]{|ws| request ws}
    end
  end

  def self.request ws
    req = {
      klass: self,
      ws: ws,
      buf: [],
    }

    ws.onopen{|handshake| ws_open handshake, req}
    ws.onbinary{|msg| ws_data msg, req}
    ws.onclose{|code, body| ws_close req}
    ws.onerror{|err| ws_error err, req}
  end

  def self.resolve(path)
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

  def self.ws_open(handshake, req)
    log "Request", handshake.path
    unless host = resolve(handshake.path) rescue nil
      log "Invalid host"
      req[:ws].close
      return
    end
    log "Connecting to", host
    EM.connect host, 22, self, req
  end

  def self.ws_data(msg, req)
    if req[:buf]
      req[:buf] << msg
    else
      req[:ssh].send_data msg
    end
  end

  def self.ws_close(req)
    log 'Client closed connection'
    req[:ssh].close_connection if req[:ssh]
  end

  def self.ws_error(err, req)
    log "ErRor...", err
    req[:ssh].close_connection if req[:ssh]
  end

  def initialize(req)
    @req=req
  end

  def log *msg
    @req[:klass].log *msg
  end

  # Connected to SSH
  def post_init
    log "Connected to SSH server"
    @req[:ssh]=self
    @req[:buf].each{|data| @req[:ssh].send_data data}
    @req[:buf] = nil
  end

  # Data from SSH
  def receive_data data
    @req[:ws].send_binary data
  end

  # SSH disconnect
  def unbind
    log 'SSH server closed connection'
    @req[:ws].close
  end
end

Server.go
