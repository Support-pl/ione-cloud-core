import json
import requests
import argparse
import sys

#########################################################
#                   Задачи:                             #
#     1. Решить проблему с названиями и неполнотой      #
#   списка: по GET запросу можно получить только те     #
#   датасеты, к которым "лично" обратиться нельзя.      #
#     2. Решить проблему с квотами                      #
#########################################################

class Startup(object):
    def __init__(self):
        self._hostname = 'freenas.support.by'
        self._user = 'root'
        self._secret = 'Nhb500Gznmcjn'
        self._ep = 'http://%s/api/v1.0' % self._hostname
    def request(self, resource, method='GET', data=None):
        if data is None:
            data = {}
        r = requests.request(
            method,
            '%s/%s/' % (self._ep, resource),
            data=json.dumps(data),
            headers={'Content-Type': "application/json"},
            auth=(self._user, self._secret),
        )
        if r.ok:
            try:
                return r.json()
            except:
                return r.text
        raise ValueError(r)
    def create_dataset(self, name):
        return self.request('storage/volume/NAS10-2/datasets', method='POST', data={
           'name': name,
        #    'quota': '1G'
        })
    def delete_dataset(self, name):
        return self.request('storage/volume/NAS10-2/datasets/%s' % name, 'DELETE')

freenas = Startup()
if sys.argv[1] == '-d' and sys.argv[2] != None:
    print freenas.delete_dataset(sys.argv[2])
elif sys.argv[1] == '-c' and sys.argv[2] != None:
    print freenas.create_dataset(sys.argv[2])