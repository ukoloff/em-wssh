require_relative 'all'

module EventMachine::Wssh
module Help

  def self.go!
    puts <<-EOT
WSSH v#{VERSION}

Available commands:
    EOT
    Exe.commands.each{|cmd, mod| puts "  #{cmd}  -"}
  end
end
end
