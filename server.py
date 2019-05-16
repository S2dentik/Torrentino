import sys

if sys.version_info >= (3, 0):
    from tpb.tpb import TPB
    from tpb.constants import ORDERS, CATEGORIES
else:
    from tpb import TPB
    from constants import ORDERS, CATEGORIES

from BaseHTTPServer import HTTPServer, BaseHTTPRequestHandler
from SocketServer import ThreadingMixIn
import threading
from urlparse import urlparse
from magnet import TorrentClient
import json

t = TPB('https://thepiratebay.org') # create a TPB object with default domain
client = TorrentClient('Downloads')
print("Torrent client initialized")

torrents = {}
torrents_lock = threading.Lock()
downloads = {}
downloads_lock = threading.Lock()

def query_from_path(path):
    query_raw = urlparse(path).query
    return dict(qc.split("=") for qc in query_raw.split("&"))

def search(handler):
    query = query_from_path(handler.path)
    if 'query' not in query:
        handler.send_error(400)
        handler.wfile.write(json.dumps({'error': "'query' is required."}))
        return
    s = t.search(query['query'])
    items = []
    with torrents_lock:
        for item in s.items():
            torrents[item.id] = item
            items.append({'title': item.title, 'size': item.size, 'seeders': item.seeders, 'id': item.id, 'category': item.category, 'sub_category': item.sub_category})
    handler.wfile.write(json.dumps(items))
    return

def download(handler):
    query = query_from_path(handler.path)
    if 'id' not in query:
        handler.send_error(400)
        handler.wfile.write(json.dumps({'error': "'id' is required."}))
        return
    id = query['id']
    if id not in torrents:
        handler.send_error(400)
        handler.wfile.write(json.dumps({'error': "Couldn't find torrent for id."}))
        return
    client.download(torrents[id].magnet_link, lambda status: handle_download_progress(status, id))
    return

def status(handler):
    items = [{
        'progress': d.progress,
        'download_speed': add_suffix(d.download_rate * 1024), 
        'upload_speed': add_suffix(d.upload_rate * 1024), 
        'num_peers': d.num_peers, 
        'state': d.state,
        'is_finished': d.is_finished,
        'eta': calculate_eta(d.download_rate * 1024, d.progress, torrents[id].size_in_bytes()),
        'id': id} for id, d in downloads.iteritems()]
    handler.wfile.write(json.dumps(items))
    return

def handle_download_progress(status, id):
    with downloads_lock:
        downloads[id] = status

def calculate_eta(speed, progress, total):
    return total * (1 - progress) / speed

def add_suffix(val):
    prefix = ['B', 'kB', 'MB', 'GB', 'TB']
    result = None
    for i in range(len(prefix)):
        if abs(val) < 1000:
            if i == 0:
                result = '%5.3g%s' % (val, prefix[i])
                break
            else:
                result = '%4.3g%s' % (val, prefix[i])
                break
        val /= 1000

    result = '%6.3gPB' % val if result is None else result
    return result.strip() + "/s"

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

# search for 'public domain' in 'movies' category
# search = t.search('game of thrones')
# item = next((x for i, x in enumerate(search.items()) if i == 2), None)
# client.download(item.magnet_link)
