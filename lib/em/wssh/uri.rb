require 'uri'

require_relative '../wssh'

module EventMachine::Wssh
class Uri

  def self.wrap uri
    return uri unless Gem.win_platform?
    z = URI uri
    return uri unless %w(wss https).include? z.scheme
    puts "Running TLS Wrapper..."
    require_relative 'tls'
    z.port=TLS.run! z.host
    z.scheme='ws'
    z.host='localhost'
    z.to_s
  end

end
end
