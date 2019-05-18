import redis

class Database(object):
  def __init__(self):
    self.r = redis.Redis(host='localhost', port=6379, db=0)

  def get(self, key):
    return self.r.hgetall(str(key))

  def set(self, key, value):
    if isinstance(value, dict):
      new_value = dict()
      for k, value in value.iteritems():
        if isinstance(value, bool):
          value = int(value)
        new_value[str(k)] = value
      value = new_value
    self.r.hmset(str(key), value)

  def keys(self):
    return self.r.keys()

