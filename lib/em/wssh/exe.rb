require_relative '../wssh'

module EventMachine::Wssh
module Exe
  def self.do!
    cmd = ARGV.shift
    help unless /\A\w+\Z/.match cmd
    cmd=cmd.downcase
    begin
      require_relative cmd
    rescue LoadError
      help
    end
    m=Module.nesting[1].const_get cmd.sub(/^./){|s|s.upcase}
    help unless m.respond_to? :go!
    m.go!
  end

  def self.help
    require_relative 'help'
    Help.go!
    exit
  end
end
end
