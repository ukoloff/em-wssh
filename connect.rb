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
