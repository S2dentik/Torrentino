# source:
# https://stackoverflow.com/questions/6051877/loading-magnet-link-using-rasterbar-libtorrent-in-python
#
# ATTENTION: This is only a example of to use a python bind of torrent library in Python for educational purposes.
#            I am not responsible for your download of illegal content or without permission.
#            Please respect the laws license permits of your country.
import libtorrent as lt
import time
import threading

class TorrentClient(object):
    def __init__(self, path):
        self.path = path
        self.start_session()

    def start_session(self):
        self.ses = lt.session()
        self.ses.listen_on(6881, 6891)
        
    def download(self, link):
        params = {
        'save_path': self.path,
        'storage_mode': lt.storage_mode_t(2),
        'paused': False,
        'auto_managed': True,
        'duplicate_is_error': True}

        handle = lt.add_magnet_uri(self.ses, link, params)
        self.ses.start_dht()
        threading.Thread(target=self._download, args=(link, handle)).start()

    def _download(self, link, handle):
        print 'downloading metadata...'
        while (not handle.has_metadata()):
            time.sleep(1)
        print 'got metadata, starting torrent download...'
        while (handle.status().state != lt.torrent_status.seeding):
            s = handle.status()
            state_str = ['queued', 'checking', 'downloading metadata', 'downloading', 'finished', 'seeding', 'allocating']
            print '%.2f%% complete (down: %.1f kb/s up: %.1f kB/s peers: %d) %s' % \
                    (s.progress * 100, s.download_rate / 1000, s.upload_rate / 1000, \
                    s.num_peers, state_str[s.state])
            time.sleep(5)
