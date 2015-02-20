#
# Simple client
#
# Fails on Windows (stdio)
# See https://groups.google.com/forum/#!topic/eventmachine/5rDIOA2uOoA
#
require 'faye/websocket'

unless ARGV.length==1
  puts <<EOT
WSSH client
Usage: #{File.basename $0} ws[s]://host[:port]/uri
EOT
  exit
end
