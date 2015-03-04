require_relative 'exe'

module EventMachine::Wssh
module Help

  Title='Show this help'

  def self.go!
    if mod = Exe.command?(ARGV.shift)
      command mod
    else
      top
    end
  end

  def self.top
    require_relative 'all'

    puts <<-EOT
WSSH suite v#{VERSION}

Usage: wssh command [parameters...]

Available commands:

    EOT
    Exe.commands.each{|cmd, mod| puts "  wssh #{cmd}\t#{mod::Title rescue nil}"}
  end

  def self.command mod
    if mod.respond_to? :help
      mod.help
    else
      puts mod::Title
    end
  end

  def self.help
    puts <<-EOT
Shows help for WSSH suite or individual commands

Usage: #{Exe.biname} [command]
    EOT
  end
end
end
