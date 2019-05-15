import sys

if sys.version_info >= (3, 0):
    from tpb.tpb import TPB
    from tpb.constants import ORDERS, CATEGORIES
else:
    from tpb import TPB
    from constants import ORDERS, CATEGORIES

from magnet import TorrentClient


t = TPB('https://thepiratebay.org') # create a TPB object with default domain
client = TorrentClient('Downloads')

print "Torrent client initialized"

# search for 'public domain' in 'movies' category
search = t.search('game of thrones')
item = next((x for i, x in enumerate(search.items()) if i == 2), None)
client.download(item.magnet_link)
