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

STDOUT.sync=true

module Stdio
  attr_accessor :buf

  def initialize(websocket)
    @ws = websocket
  end

  def ws_send data
    @ws.send data.unpack 'C*'
  end

  def receive_data data
    if buf
      buf.push data
    else
      ws_send data
    end
  end

  def unbind
    EM.stop_event_loop
  end
end

EM.run do
  ws = Faye::WebSocket::Client.new ARGV[0]
  stdio = EM.attach $stdin, Stdio, ws
  stdio.buf = []

  ws.on :open do |event|
    stdio.buf.each{|data| ws.ws_send data}
    stdio.buf=nil
  end

  ws.on :message do |event|
    print event.data.pack 'C*'
  end

  ws.on :close do
    EM.stop_event_loop
  end
end
