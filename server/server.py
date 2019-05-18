import sys
from BaseHTTPServer import HTTPServer, BaseHTTPRequestHandler
from SocketServer import ThreadingMixIn
import threading
from urlparse import urlparse
from handlers import search, download, status

router = {
    '/search': search,
    '/download': download,
    '/status': status
}

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.protocol_version = 'HTTP/1.0'
        p = urlparse(self.path).path
        if p not in router:
            self.send_error(404, 'The route was not found')
            self.end_headers()
        else:
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            router[p](self)
        return

class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    """Handle requests in a separate thread."""

if __name__ == '__main__':
    server = ThreadedHTTPServer(('192.168.31.31', 10000), Handler)
    print('Starting server, use <Ctrl-C> to stop')
    server.serve_forever()
