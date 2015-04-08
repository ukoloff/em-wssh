require_relative '../wssh'

module EventMachine::Wssh
module Service
  attr_reader :options

  def log *msg
    return if options[:mute]
    msg.unshift "[#{Time.now}]"
    STDOUT << msg*' '+"\n"
  end

  def helptions
    puts <<-EOF

  -a --all         Listen to all interfaces
  -b --base=dir    Set home directory
  -d --daemon      Run daemonized
  -h --help        Show this help
  -l --listen=port Listen to port
  -p --ping[=sec]  Periodic ping
  -v --version     Show version
EOF
    exit 1
  end

  def getopt
    require 'getoptlong'
    opts = GetoptLong.new(
      ['-l', '--listen', GetoptLong::REQUIRED_ARGUMENT],
      ['-b', '--base', GetoptLong::REQUIRED_ARGUMENT],
      ['-d', '--daemon', GetoptLong::NO_ARGUMENT],
      ['-a', '--all', GetoptLong::NO_ARGUMENT],
      ['-v', '--version', GetoptLong::NO_ARGUMENT],
      ['-p', '--ping', GetoptLong::OPTIONAL_ARGUMENT],
    )
    begin
      opts.each do |opt, arg|
        case opt
        when '-d'
          options[:daemon]=true
        when '-l'
          options[:port]=arg
        when '-b'
          options[:base]=File.expand_path arg
        when '-a'
          options[:host]='0.0.0.0'
        when '-p'
          arg=arg.to_i
          options[:ping]= arg<1 ? 50 : arg
        when '-v'
          puts VERSION
          exit 1
        end
      end
    rescue
      help
    end
    args=options[:args]
    args=args.nil? ? [] : [args] unless Array===args
    help if args.length!=ARGV.length
    args.each{|arg| options[arg]=ARGV.shift}
  end

  def homebase
    x = File.expand_path '..', __FILE__
    x = File.dirname x until File.exists? File.join x, 'Gemfile'
    x
  end

  def path(sym)
    File.join options[:base]||=homebase, options[sym]
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
    STDOUT.sync=true
    EM.run{ listen! }
  end

  def go!
    getopt
    daemonize?
    log "Listening on #{options[:host]}:#{options[:port]}"
    pid
    loop!
  end

end
end
