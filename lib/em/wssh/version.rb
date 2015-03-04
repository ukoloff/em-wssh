require_relative '../wssh'

module EventMachine::Wssh
module Version

  Title = 'Show WSSH version'

  def self.go!
    puts VERSION
  end
end
end
