# em-wssh

[![Gem Version](https://badge.fury.io/rb/em-wssh.svg)](http://badge.fury.io/rb/em-wssh)

Ruby version of ssh thru websocket proxying.

[Original version](https://github.com/ukoloff/wssh) uses Node.js

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'em-wssh'
```

And then execute:

```sh
$ bundle
```

Or install it yourself as:

```sh
$ gem install em-wssh
```

## Usage

Single command `wssh` is exported. Sometimes it should be `bundle exec wssh`.

### WSSH Server

To run WSSH server say `wssh server`.

You can set some options for server, ie:

Most useful option is `--base=path` (or `-b`). It set path, where server files stored.
By default this path is where gem installed. To use current directory say `wssh server -b.`

This `base` path is used to locate `hosts.yml` file, which maps host requested by user to real servers.
See [sample](hosts.yml). One can define direct map or regexp-style mapping (denoted by // with optional //i).
If multiple regexps match user host, the last one wins.
To disable connecting to host (or all hosts for regexp) map it to null or false.

The `base` also is root for log file and pid file, created by server.

Parameters `--listen=port` (`-l`) and `--all` (`-a`) define on what address server will listen.
By default it is `localhost:4567`.

Parameter `--daemon` will force server to go in background.

### nginx

Directly exposing WSSH server to Internet is not a good idea.
One should better install nginx (with TLS) and [force it to redirect](nginx/ssh)
WSSH connections to WSSH server.

### WSSH Client

Client is started with `wssh client URI`, eg `wssh client ws://localhost:4567`.

Running client from terminal is not very useful. It should be called by ssh client:

```sh
ssh -o ProxyCommand='wssh client wss://server.host.com/ssh/%h' sshd.local
```

By default nginx has 60 seconds timeout. To prevent idle connection to drop,
one can use `ServerAliveInterval` parameter:

```sh
ssh -o ProxyCommand='wssh client wss://server.host.com/ssh/%h' -o ServerAliveInterval=50 sshd.local
```

### WSSH Proxy

WSSH client is in fact unusable on Windows.
It can be impractical when we create a lot of SSH connections (eg with Capistrano mass deploy).

In these cases run `wssh connect URI`, it will listen to TCP port (3122 by default) and will work
as normal HTTP proxy, so proxy-capable clients (PuTTY/Plink and Net::SSH) can use it to connect to SSH servers.

```ruby
#!/usr/bin/env ruby

require 'net/ssh'
require 'net/ssh/proxy/http'

x=Net::SSH.start 'sshd.local', 'root',
  proxy: Net::SSH::Proxy::HTTP.new('localhost', 3122)

puts x.exec! 'hostname'
```

Proxy allows the same command line parameters as server.
For proxy parameter `--ping` may be useful,
it forces proxy to periodically send Websocket ping packets to server
for nginx to not drop connection on timeout.

## API

WSSH server, client or proxy can be start programmaticaly:

```ruby
require 'em/wssh/server'

s=EventMachine::Wssh::Server
s.options.merge! base: '.'
s.loop!
```

```ruby
require 'em/wssh/client'

c=EventMachine::Wssh::Client
c.options[:uri]='wss://server.host.com/ssh/sshd.local'
c.loop!
```

```ruby
require 'em/wssh/connect'

p=EventMachine::Wssh::Connect
p.options.merge! base: '.', all: true, uri: 'wss://server.host.com/ssh/sshd.local'
p.loop!
```

Use `go!` method instead `loop!` to mimic cli behavour (command line parsing).

Some options are not accesible to `wssh` command and can be used only programmaticaly.

### Ephemeral module

Eg, EventMachine::Wssh::Connect has option `onlisten` that allows listening to ephemeral port:

```ruby
#!/usr/bin/env ruby

require 'net/ssh'
require 'net/ssh/proxy/http'
require 'em/wssh/connect'

q=Queue.new
c=EventMachine::Wssh::Connect
c.options.merge!(
  port: 0,
  uri: 'wss://server.host.com/ssh',
  onlisten: Proc.new{|port| q.push port},
)

Thread.new{c.loop!}

puts "Port=#{port=q.pop}"

x=Net::SSH.start 'sshd.local', 'root',
  proxy: Net::SSH::Proxy::HTTP.new('localhost', port)

puts x.exec! 'hostname'
```

Unfortunately, EventMachine fails to run in thread inside Capistrano.
But Connect proxy still can run in separate process.
To do this, module Ephemeral was forged:

```ruby
task :wssh do
  require 'net/ssh/proxy/http'
  require 'em/wssh/ephemeral'

  port = EventMachine::Wssh::Ephemeral.allocate 'ws://localhost:4567/test'

  proxy = Net::SSH::Proxy::HTTP.new 'localhost', port

  roles(:all).each{|h| h.wssh_proxy proxy }
end

class SSHKit::Host
  def wssh_proxy proxy
    @ssh_options[:proxy]=proxy
  end
end
```
Use this task `cap stage wssh task(s)...` to tunnel all Capistrano ssh traffic through
WSSH server.

## Data flow

Normal SSH session is very simple:

  * SSH Client
  * TCP Connection
  * SSH Server, listening on TCP port 22

WSSH session is:

  * SSH Client with -o ProxyCommand='wssh client WSSH-URI'
  * WSSH client listening to its stdin
  * Websocket (HTTP/HTTPS) connection to nginx
  * nginx [configured](nginx/ssh) to redirect connection to WSSH server
  * Another Websocket connection from nginx to WSSH server
  * WSSH server, listening to dedicated TCP port (4567 by default)
  * Normal TCP connection
  * Normal SSH Server, listening on TCP port 22

And nginx stage can be omited in development/testing scenarios.

When using WSSH Proxy this path is even longer:

  * SSH Client, capable to connect via HTTP proxy (eg PuTTY/PLink or Net::SSH)
  * TCP connection to local proxy
  * `wssh connect` listening to dedicated port (3122 by default)
  * Websocket (HTTP/HTTPS) connection to nginx
  * nginx [configured](nginx/ssh) to redirect connection to WSSH server
  * Another Websocket connection from nginx to WSSH server
  * WSSH server, listening to dedicated TCP port (4567 by default)
  * Normal TCP connection
  * Normal SSH Server, listening on TCP port 22

## Windows bugs

Windows installation of EventMachine has a few bugs:

  1. Using STDIN [blocks](https://groups.google.com/forum/#!topic/eventmachine/5rDIOA2uOoA) all other connections
  2. By default SSL/TLS is not available
  3. No root certificates available ([Fix](https://github.com/ukoloff/openssl-win-root) exists)

So, pure EventMachine package would be almost unusable on MS Windows.

To fix this multithreaded TLS wrapper is automagically started by `wssh connect`.

WSSH client is still unusable on Windows :-(

## See also

  * [Node.js version](https://github.com/ukoloff/wssh)
  * [Python version](https://github.com/progrium/wssh)

## Credits

  * [nginx](http://nginx.org/)
  * [Ruby](https://www.ruby-lang.org/)
  * [EventMachine](https://github.com/eventmachine/eventmachine)
  * [EM-WebSocket](https://github.com/igrigorik/em-websocket)
  * [faye-websocket](https://github.com/faye/faye-websocket-ruby)
  * [Node.js](http://nodejs.org/)
  * [OpenSSH](http://www.openssh.com/)
  * [Net::SSH](https://github.com/net-ssh/net-ssh)
  * [PuTTY](http://www.chiark.greenend.org.uk/~sgtatham/putty/)
