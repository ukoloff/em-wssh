require_relative 'all'

module EventMachine::Wssh
module Help

  def self.go!
    puts <<-EOT
WSSH suite v#{VERSION}

Usage: wssh command [parameters...]

Available commands:

    EOT
    Exe.commands.each{|cmd, mod| puts "  wssh #{cmd}\t#{mod::Title rescue nil}"}
  end
end
end
