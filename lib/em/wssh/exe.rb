require_relative '../wssh'

module EventMachine::Wssh
module Exe
  def self.do!
    cmd = ARGV.shift
    throw "Invalid command '#{cmd}'" unless /\A\w+\Z/.match cmd
    require_relative cmd
  end
end
end
