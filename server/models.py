import json

class ComplexEncoder(json.JSONEncoder):
    def default(self, o):
        if hasattr(o, 'reprJSON'):
            return o.reprJSON()
        return json.JSONEncoder.default(self, o)

class Torrent():
    def __init__(self, title, size, seeders, id, category, sub_category, magnet_link, status=None, path=None):
        self.title = title
        self.size = size
        self.seeders = seeders
        self.id = id
        self.category = category
        self.sub_category = sub_category
        self.magnet_link = magnet_link
        self.status = status
        self.path = path

    def reprJSON(self):
        h = {
            'title': self.title,
            'size': self.size, 
            'seeders': self.seeders, 
            'id': self.id, 
            'category': self.category, 
            'sub_category': self.sub_category,
            'magnet_link': self.magnet_link
        }
        if self.status is not None:
            h['status'] = self.status.reprJSON()
        if self.path is not None:
            h['path'] = self.path

        return h

    def reprDB(self):
        j = self.reprJSON()
        if 'status' in j:
            j['status'] = json.dumps(j['status'])
        return j

    def size_in_bytes(self):
        prefixes = ['B', 'K', 'M', 'G', 'T']
        size_comps = self.size.split(' ')
        for i in range(len(prefixes)):
            if size_comps[1].startswith(prefixes[i]):
                return float(size_comps[0]) * (1024 ** i)
        return float(size_comps[0])

def dict_to_torrent(d):
    status = None
    if 'status' in d:
        s = d['status']
        if isinstance(s, dict):
            status = dict_to_download_status(s)
        elif isinstance(s, str):
            status = dict_to_download_status(json.loads(s))
    return Torrent(
        d.get('title', ''),
        d.get('size', '0B'),
        int(d.get('seeders', 0)),
        d.get('id', ''),
        d.get('category', ''),
        d.get('sub_category', ''),
        d.get('magnet_link', ''),
        status,
        d.get('path', '')
    )

class DownloadStatus():
    def __init__(self, progress, download_rate, upload_rate, num_peers, state, is_finished, eta=None):
        self.progress = progress
        self.download_rate = download_rate
        self.upload_rate = upload_rate
        self.num_peers = num_peers
        self.state = state
        self.is_finished = is_finished
        self.eta = eta

    def reprJSON(self):
        h = {
            'progress': self.progress,
            'download_speed': self.download_rate,
            'upload_speed': self.upload_rate,
            'num_peers': self.num_peers,
            'state': self.state,
            'is_finished': self.is_finished
        }
        if self.eta is not None:
            h['eta'] = self.eta

        return h

def dict_to_download_status(dict):
    return DownloadStatus(
        float(dict.get('progress', 0)),
        float(dict.get('download_speed', 0)),
        float(dict.get('upload_speed', 0)),
        int(dict.get('num_peers', 0)),
        str(dict.get('state', 'Downloading')),
        bool(dict.get('is_finished', False)),
        int(dict.get('eta', 0))
    )
