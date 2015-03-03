module Service
  attr_reader :options

  def log *msg
    msg.unshift "[#{Time.now}]"
    puts msg*' '
  end

  def helptions
    puts <<-EOF

  -l --listen=port Listen to port
  -a --all         Listen to all interfaces
  -d --daemon      Run daemonized
  -h --help        Show this help
EOF
    exit 1
  end


  def getopt
    require 'getoptlong'
    opts = GetoptLong.new(
      ['-l', '--listen', GetoptLong::REQUIRED_ARGUMENT],
      ['-d', '--daemon', GetoptLong::NO_ARGUMENT],
      ['-a', '--all', GetoptLong::NO_ARGUMENT],
    )
    begin
      opts.each do |opt, arg|
        case opt
        when '-d'
          options[:daemon]=true
        when '-l'
          options[:port]=arg
        when '-a'
          options[:host]='0.0.0.0'
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
    getopt
    daemonize?
    log "Listening on #{options[:host]}:#{options[:port]}"
    pid
    loop!
  end

end
