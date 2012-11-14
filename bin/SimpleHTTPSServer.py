'''
SimpleSecureHTTPServer.py - simple HTTP server supporting SSL.

You can copy this to /usr/lib/python2.7/ and then run the following command
  python -m SimpleHTTPSServer
It will then serve directory listing web pages for $PWD.

- replace fpem with the location of your .pem server file.
- the default port is 443.

usage: python SimpleSecureHTTPServer.py
'''
import os,sys
from SocketServer import BaseServer
from BaseHTTPServer import HTTPServer
from SimpleHTTPServer import SimpleHTTPRequestHandler
from OpenSSL import SSL
sys.path.reverse()
sys.path.append("/home/sam/sandbox/simple python ssl server/Python 2.7")
sys.path.reverse()
import socket


class SecureHTTPServer(HTTPServer):
    def __init__(self, server_address, HandlerClass):
        BaseServer.__init__(self, server_address, HandlerClass)
        ctx = SSL.Context(SSL.SSLv23_METHOD)
        #server.pem's location (containing the server private key and
        #the server certificate).
        #fpem = './localhost.pem'
        fpem = '/home/sam/certs/farcry.irt.drexel.edu/farcry.irt.drexel.edu.pem'
        ctx.use_privatekey_file (fpem)
        ctx.use_certificate_file(fpem)
        self.socket = SSL.Connection(ctx, socket.socket(self.address_family,self.socket_type))
        self.server_bind()
        self.server_activate()
    def shutdown_request(self,request): request.shutdown()


class SecureHTTPRequestHandler(SimpleHTTPRequestHandler):
    def setup(self):
        self.connection = self.request
        self.rfile = socket._fileobject(self.request, "rb", self.rbufsize)
        self.wfile = socket._fileobject(self.request, "wb", self.wbufsize)


def test(HandlerClass = SecureHTTPRequestHandler,
         ServerClass = SecureHTTPServer):
    server_address = ('', 8000) # (address, port)
    httpd = ServerClass(server_address, HandlerClass)
    sa = httpd.socket.getsockname()
    print "Serving HTTPS on", sa[0], "port", sa[1], "..."
    print "Use ^C to shut down server."
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print "Shutting down server..."


if __name__ == '__main__':
    test()
