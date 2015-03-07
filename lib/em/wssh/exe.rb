require_relative '../wssh'

module EventMachine::Wssh
module Exe
  def self.command? cmd
    return unless /\A\w+\Z/.match cmd
    cmd=cmd.downcase
    begin
      require_relative cmd
    rescue LoadError
      return
    end
    m=Module.nesting[1].const_get cmd.sub(/^./){|s|s.upcase} rescue nil
    return unless Module===m and m.respond_to? :go!
    m
  end

  def self.commands
    m=Module.nesting[1]
    Hash[
      m.constants
      .map{|n|m.const_get n}
      .grep(Module)
      .select{|m| m.respond_to? :go!}
      .select{|m| m.const_defined? :Title}
      .map{|m| [m.name.split(/\W+/).last.downcase, m]}
      .sort_by{|x| x[0]}
    ]
  end

  def self.do!
    mod = command? ARGV.shift
    help unless mod
    mod.go!
  end

  def self.help
    require_relative 'help'
    Help.go!
    exit
  end

  def self.usage
    "Usage: wssh "+File.basename(caller_locations.first.path).sub(/[.][^.]*\Z/, '')
  end
end
end
