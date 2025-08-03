import mysql.connector
from pprint import pprint

cfg = {
    'user':         'appuser',
    'password':     'Secret123',
    'host':         '127.0.0.1',
    'port':         3306,
    'database':     'coldchain',
    'auth_plugin':  'mysql_native_password'
}

cnx = mysql.connector.connect(**cfg)
cur = cnx.cursor(dictionary=True)
cur.execute("SELECT * FROM batches;")
rows = cur.fetchall()
pprint(rows)

cur.close()
cnx.close()
