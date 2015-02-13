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

puts "Running d=#{daemon} on port #{port}"
