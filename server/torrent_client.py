# source:
# https://stackoverflow.com/questions/6051877/loading-magnet-link-using-rasterbar-libtorrent-in-python
#
# ATTENTION: This is only a example of to use a python bind of torrent library in Python for educational purposes.
#            I am not responsible for your download of illegal content or without permission.
#            Please respect the laws license permits of your country.
import libtorrent as lt
import time
import threading
import json

from models import DownloadStatus

class TorrentClient(object):
    def __init__(self, path):
        self.path = path
        self.start_session()

    def start_session(self):
        self.ses = lt.session()
        self.ses.listen_on(6881, 6891)
        
    def download(self, link, handler):
        params = {
        'save_path': self.path,
        'storage_mode': lt.storage_mode_t(2),
        'paused': False,
        'auto_managed': True,
        'duplicate_is_error': True}

        handle = lt.add_magnet_uri(self.ses, link, params)
        self.ses.start_dht()
        threading.Thread(target=self._download, args=(link, handle, handler)).start()

    def _download(self, link, handle, handler):
        print 'downloading metadata...'
        handler(DownloadStatus(0, 0, 0, 0, "Downloading Metadata", False))
        while (not handle.has_metadata()):
            time.sleep(1)
        print 'got metadata, starting torrent download...'
        while (handle.status().state != lt.torrent_status.seeding):
            s = handle.status()
            self.notify(s, handler)
            time.sleep(2)
        self.notify(handle.status(), handler)

    def notify(self, s, handler):
        state_str = ['Queued', 'Checking', 'Downloading Metadata', 'Downloading', 'Finished', 'Finished', 'Allocating']
        is_finished = s.state in [lt.torrent_status.finished, lt.torrent_status.seeding]
        handler(DownloadStatus(s.progress, s.download_rate / 1000, s.upload_rate / 1000, s.num_peers, state_str[s.state], is_finished))
