# em-wssh

Ruby version of ssh thru websocket proxying.

[Original version](https://github.com/ukoloff/wssh) uses Node.js

## Data flow

Normal SSH session is very simple:

  * SSH Client
  * TCP Connection
  * SSH Server, listening on TCP port 22

WSSH session is:

  * SSH Client with -o ProxyCommand='ruby client.rb WSSH-URI'
  * client.rb listening to its stdin
  * Websocket (HTTP/HTTPS) connection to nginx
  * nginx [configured](nginx/ssh) to redirect connection to WSSH server
  * Another Websocket connection from nginx to WSSH server
  * WSSH server, listening to dedicated TCP port (4567 by default)
  * Normal TCP connection
  * Normal SSH Server, listening on TCP port 22

And nginx stage can be omited in development/testing scenarios.

In some scenarios this path can be even longer:

  * SSH Client, capable to connect via HTTP proxy (eg PuTTY/PLink)
  * TCP connection to local proxy
  * connect.rb listening to dedicated port (3122 by default)
  * Websocket (HTTP/HTTPS) connection to nginx
  * nginx [configured](nginx/ssh) to redirect connection to WSSH server
  * Another Websocket connection from nginx to WSSH server
  * WSSH server, listening to dedicated TCP port (4567 by default)
  * Normal TCP connection
  * Normal SSH Server, listening on TCP port 22

## Windows bugs

Windows installation of EventMachine has two bugs:

  1. Using STDIN blocks all other connections
  2. By default SSL/TLS is not available

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
  * [PuTTY](http://www.chiark.greenend.org.uk/~sgtatham/putty/)
