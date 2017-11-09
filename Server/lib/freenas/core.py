import json
import requests
import sys

ip_addr, quota, passwd, api_pass = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

def getNewUserID():
    users = requests.get(
        'http://freenas.support.by/api/v1.0/account/users/',
        auth=('root', 'Nhb500Gznmcjn'),
        headers={'Content-Type': 'application/json'},
    ).json()
    ids = []
    for user in users:
        ids.append(user['bsdusr_uid'])
    return max(ids) + 1

def rm_dataset(name):
    return requests.delete(
        'http://freenas.support.by/api/v1.0/storage/volume/NAS10-2/%s' % name,
        auth=('root', api_pass),
        headers={'Content-Type': 'application/json'},
        verify=False
    )#.text

def mk_dataset(name, quota):
    r = requests.post(
        'http://freenas.support.by/api/v1.0/storage/volume/NAS10-2/datasets/',
        auth=('root', api_pass),
        headers={'Content-Type': 'application/json', 'Vary': 'Accept'},
        verify=True,
        data=json.dumps({
            'name': name,
            'comments': 'COMMENT',
            'quote': quota,
            'reservation': quota
        }),
    )
    return r.json()

try:
    tmp = sys.argv[5] == 'rm'
except:
    print mk_dataset(ip_addr, quota)
else:
    print rm_dataset(ip_addr)


# r = requests.post(
#     'http://freenas.support.by/api/v1.0/storage/dataset/tank/',
#     auth=('root', api_pass),
#     headers={'Content-Type': 'application/json'},
#     verify=False,
#     data=json.dumps({
#         'bsdusr_uid': uid,
#         'bsdusr_username': ip_addr,
#         'bsdusr_mode': '755',
#         'bsdusr_creategroup': True,
#         'bsdusr_password': passwd,
#         'bsdusr_shell': '/usr/local/bin/bash',
#         'bsdusr_full_name': ip_addr,
#         'bsdusr_home': "/mnt/NAS10-2/%s" % ip_addr
#     }),
# )
# print r.text