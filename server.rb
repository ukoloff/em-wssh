module Server
  @options={
    host: 'localhost',
    port: 4567,
    daemon: false,
    root: File.dirname(__FILE__),
    hosts: 'hosts.yml',
    log: 'log/wsshd.log',
    pid: 'tmp/pids/wsshd.pid',
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

Usage: ruby #{File.basename __FILE__} [options...]

  -l --listen=port Listen to port
  -a --all         Listen to all interfaces
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
    help unless ARGV.empty?
  end

  def self.path(sym)
    File.join options[:root], options[sym]
  end

  def self.mkdir(sym)
    require 'fileutils'
    FileUtils.mkdir_p File.dirname file=(path sym)
    file
  end

  def self.daemonize!
    throw 'Cannot daemonize on Windows!' if Gem.win_platform?

    log "Going on in background..."

    f = File.open mkdir(:log), 'a'
    f.sync=true

    STDIN.reopen '/dev/null'
    STDOUT.reopen f
    STDERR.reopen f

    Process.daemon true, true
  end

  def self.daemonize?
    daemonize! if options[:daemon]
  end

  def self.pid
    File.write p=mkdir(:pid), $$
    at_exit do
      log "Exiting..."
      File.unlink p
    end
  end

  module Ssh
    attr_accessor :req

    def initialize req
      self.req=req
    end

    def log *msg
      req.log *msg
    end

    def post_init
      log "Connected to SSH server"
      req.ssh=self
      req.buf.each{|data| send_data data}
      req.buf=nil
    end

    def receive_data data
      req.ws.send_binary data
    end

    def unbind
      log 'SSH server closed connection'
      req.bye
    end
  end

  class Req
    attr_accessor :ws, :buf, :ssh

    Server=Module.nesting[1]

    def self.count
      @n||=0
      @n+=1
    end

    def initialize ws
      self.ws=ws
      self.buf=[]

      @count=self.class.count

      ws.onopen{|handshake| onopen handshake}
      ws.onbinary{|msg| ondata msg}
      ws.onclose{|code, body| onclose}
      ws.onerror{|err| onerror err}
    end

    def log *msg
      Server.log "<#{@count}>", *msg
    end

    def onopen handshake
      log "Request", handshake.path
      unless host = resolve(handshake.path) rescue nil
        log "Invalid host"
        bye
        return
      end
      log "Connecting to", host
      EM.connect host, 22, Ssh, self
    end

    def ondata msg
      if buf
        buf << msg
      else
        ssh.send_data msg
      end
    end

    def onclose
      log 'Client closed connection'
      bye
    end

    def onerror err
      log "Websocket error", err
      bye
    end

    def resolve(path)
      path = path.to_s
      .split(/[^-.\w]+/)
      .select{|s|s.length>0}
      .select{|s|!s.match /^[-_.]|[-_.]$/}
      .last
      yml = YAML.load_file Server.path(:hosts)

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

    def bye
      ssh.close_connection if ssh
      ws.close if ws
      instance_variables.each{|v| remove_instance_variable v unless :'@count'==v}
    end
  end

  def self.listen!
    EM::WebSocket.run host: options[:host], port: options[:port] do |ws|
      Req.new ws
    end
  end

  def self.loop
    require 'yaml'
    require 'em-websocket'
    EM.run{ listen! }
  end

  def self.go!
    getopt
    daemonize?
    log "Listening on #{options[:host]}:#{options[:port]}"
    pid
    loop
  end

  go!

end
