module Service
  attr_reader :options

  def log *msg
    msg.unshift "[#{Time.now}]"
    puts msg*' '
  end

  def path(sym)
    File.join options[:root], options[sym]
  end

  def mkdir(sym)
    require 'fileutils'
    FileUtils.mkdir_p File.dirname file=(path sym)
    file
  end

  def daemonize!
    throw 'Cannot daemonize on Windows!' if Gem.win_platform?

    log "Going on in background..."

    f = File.open mkdir(:log), 'a'
    f.sync=true

    STDIN.reopen '/dev/null'
    STDOUT.reopen f
    STDERR.reopen f

    Process.daemon true, true
  end

  def daemonize?
    daemonize! if options[:daemon]
  end

  def pid
    File.write p=mkdir(:pid), $$
    at_exit do
      log "Exiting..."
      File.unlink p
    end
  end

  def loop!
    self::Need.each{|f| require f}
    EM.run{ listen! }
  end

  def go!
    require 'getoptlong'
    getopt
    daemonize?
    log "Listening on #{options[:host]}:#{options[:port]}"
    pid
    loop!
  end

end
