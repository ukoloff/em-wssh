require_relative 'all'

module EventMachine::Wssh
module Help
  def self.go!
    m=Module.nesting[1]
    list=m.constants
    .map{|n|m.const_get n}
    .grep(Module)
    .select{|m| m.respond_to? :go!}
    .map{|m| m.name.split(/\W+/).last.downcase}
    .sort
    puts <<-EOT
WSSH v#{VERSION}

Available commands: #{list*', '}
    EOT
  end
end
end
