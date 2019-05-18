from urlparse import urlparse
import json
import threading
import urllib

from models import ComplexEncoder, Torrent, dict_to_download_status, dict_to_torrent
from database import Database
from torrent_client import TorrentClient
from tpb import TPB

t = TPB('https://thepiratebay.org') # create a TPB object with default domain
client = TorrentClient('Downloads')

database = Database()

def search(handler):
    query = query_from_path(handler.path)
    if 'query' not in query:
        handler.send_error(400)
        handler.wfile.write(json.dumps({'error': "'query' is required."}))
        return
    s = t.search(urllib.unquote(query['query']))
    items = []
    for item in s.items():
        torrent = Torrent(item.title, item.size, item.seeders, item.id, item.category, item.sub_category, item.magnet_link)
        database.set(item.id, torrent.reprDB())
        items.append(torrent)
    handler.wfile.write(json.dumps(items, cls=ComplexEncoder))
    return

def download(handler):
    query = query_from_path(handler.path)
    if 'id' not in query:
        handler.send_error(400)
        handler.wfile.write(json.dumps({'error': "'id' is required."}))
        return
    id = query['id']
    if id not in database.keys():
        handler.send_error(400)
        handler.wfile.write(json.dumps({'error': "Couldn't find torrent for id."}))
        return
    torrent = dict_to_torrent(database.get(id))
    client.download(torrent.magnet_link, lambda status: handle_download_progress(status, id))
    return

def status(handler):
    items = []
    for id in database.keys():
        torrent = dict_to_torrent(database.get(id))
        if torrent.status is not None:
            torrent.status.eta = calculate_eta(float(torrent.status.download_rate) * 1024, float(torrent.status.progress), torrent.size_in_bytes())
            items.append(torrent)
    handler.wfile.write(json.dumps(items, cls=ComplexEncoder))
    return

def handle_download_progress(status, id):
    torrent_dict = database.get(id)
    if torrent_dict is None:
        return
    torrent = dict_to_torrent(torrent_dict)
    torrent.status = status
    database.set(id, torrent.reprDB())

def calculate_eta(speed, progress, total):
    if speed == 0:
        return 0
    return total * (1 - progress) / speed

def query_from_path(path):
    query_raw = urlparse(path).query
    return dict(qc.split("=") for qc in query_raw.split("&"))