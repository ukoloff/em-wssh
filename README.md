# em-wssh

[![Gem Version](https://badge.fury.io/rb/em-wssh.svg)](http://badge.fury.io/rb/em-wssh)

Ruby version of ssh thru websocket proxying.

[Original version](https://github.com/ukoloff/wssh) uses Node.js

## Installation

Add this line to your application's Gemfile:

```ruby
  gem 'em-wssh' if Gem.win_platform?
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
  proxy: Net::SSH::Proxy::HTTP.new 'localhost', 3122

puts x.exec! 'hostname'
```

## API


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
  onport: Proc.new{|port| q.push port},
)

Thread.new{c.loop!}

puts "Port=#{port=q.pop}"

x=Net::SSH.start 'sshd.local', 'root',
  proxy: Net::SSH::Proxy::HTTP.new 'localhost', port

puts x.exec! 'hostname'
```

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

In some scenarios this path can be even longer:

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
  3. No root certificates available ([Fixed](https://github.com/ukoloff/openssl-win-root))

So, this package is in fact almost unusable on MS Windows.

The only exception: if you connect to Non-TLS WSSH server
(ws: or http:, not wss: or https:), you **can** start connect.rb
and then use SSH client, capable to connect via HTTP proxy.

To connect to TLS WSSH server, you should use Node.js version.

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
