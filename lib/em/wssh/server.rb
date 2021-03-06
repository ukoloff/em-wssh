require_relative 'service'

module EventMachine::Wssh
module Server
  extend Service

  Title='WSSH daemon redirects Websocket to sshd'

  Need=%w(yaml em-websocket)

  @options={
    host: 'localhost',
    port: 4567,
    daemon: false,
    hosts: 'hosts.yml',
    log: 'log/wsshd.log',
    pid: 'tmp/pids/wsshd.pid',
  }

  def self.help
    require_relative 'exe'
    puts <<-EOF
Proxy ssh connection through websocket

#{Exe.usage} [options...]
EOF
    helptions
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

      log "Connect from", Socket.unpack_sockaddr_in(ws.get_peername)[1]

      ws.onopen{|handshake| onopen handshake}
      ws.onbinary{|msg| ondata msg}
      ws.onclose{|code, body| onclose}
      ws.onerror{|err| onerror err}
    end

    def log *msg
      Server.log "<#{@count}>", *msg
    end

    def onopen handshake
      xf=handshake.headers_downcased['x-forwarded-for']
      log "Forwarded for", xf if xf
      log "Request", handshake.path
      unless host = resolve(handshake.path) rescue nil
        log "Invalid host"
        bye
        return
      end
      log "Connecting to", host
      EM.connect host, 22, Ssh, self
      pinger
    end

    def pinger
      return unless t=Server.options[:ping]
      @timer=EM::PeriodicTimer.new(t){ws.ping if ws}
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
      @timer.cancel if @timer
      instance_variables.each{|v| remove_instance_variable v if '@count'!=v.to_s}
    end
  end

  def self.listen!
    EM::WebSocket.run host: options[:host], port: options[:port] do |ws|
      Req.new ws
    end
  end
end
end
