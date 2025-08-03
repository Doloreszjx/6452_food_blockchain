import os, json, hashlib, subprocess
import mysql.connector
from datetime import datetime

# Merkle Root 计算函数同前
def compute_merkle_root(hash_list):
    if not hash_list:
        return None
    current = list(hash_list)
    while len(current) > 1:
        if len(current) % 2 == 1:
            current.append(current[-1])
        next_level = []
        for i in range(0, len(current), 2):
            combined = bytes.fromhex(current[i]) + bytes.fromhex(current[i+1])
            next_level.append(hashlib.sha256(combined).hexdigest())
        current = next_level
    return current[0]

IPFS_CLI_PATH = r"D:\go-ipfs\ipfs.exe"

def upload_file_via_cli(path):
    result = subprocess.run(
        [IPFS_CLI_PATH, 'add', '-Q', path],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )
    if result.returncode != 0:
        raise RuntimeError(f"IPFS add failed: {result.stderr}")
    return result.stdout.strip()

# MySQL 连接配置
cfg = {
    'user':         'appuser',
    'password':     'Secret123',
    'host':         '127.0.0.1',
    'port':         3306,
    'database':     'coldchain',
    'auth_plugin':  'mysql_native_password'
}

def process_batch_file(path):
    # 1. 读取 JSON
    with open(path, 'r', encoding='utf-8') as f:
        records = json.load(f)
    batch_id = os.path.basename(path).split('_')[0]

    # 2. 计算 Merkle Root
    merkle_root = compute_merkle_root([rec['hash'] for rec in records])

    # 3. 上传到 IPFS CLI
    cid = upload_file_via_cli(path)
    print(f"[IPFS CLI] Batch {batch_id} → CID={cid}, MerkleRoot={merkle_root}")

    # 4. 写入 MySQL
    cnx = mysql.connector.connect(**cfg)
    cur = cnx.cursor()
    cur.execute("""
        INSERT IGNORE INTO batches
          (batch_id, ipfs_cid, merkle_root, record_count, created_at)
        VALUES (%s, %s, %s, %s, %s)
    """, (batch_id, cid, merkle_root, len(records), datetime.utcnow()))
    cnx.commit()
    cur.close()
    cnx.close()

def main():
    for fname in os.listdir('./batches'):
        if fname.endswith('.json'):
            process_batch_file(os.path.join('./batches', fname))

if __name__ == '__main__':
    main()
