import json
import datetime
import os
from web3 import Web3
from dotenv import load_dotenv

# —— 1. 加载环境 & 初始化 Web3 ——
load_dotenv()
RPC   = os.getenv("WEB3_RPC_URL")
KEY   = os.getenv("PRIVATE_KEY")
ADDR  = Web3.to_checksum_address(os.getenv("CONTRACT_ADDRESS"))
ABI   = json.load(open(os.getenv("ABI_PATH"), 'r'))

w3      = Web3(Web3.HTTPProvider(RPC))
acct    = w3.eth.account.from_key(KEY)
contract = w3.eth.contract(address=ADDR, abi=ABI)


def to_unix(ts_iso: str) -> int:
    # "2025-07-31T01:56:14Z" → UNIX
    dt = datetime.datetime.fromisoformat(ts_iso.replace("Z", "+00:00"))
    return int(dt.timestamp())


def send_upload(rec: dict):
    """将一条 JSON 记录上传到链上"""
    # 1) 时间戳
    unix_ts = to_unix(rec["ts"])
    # 2) 数值转整数（如果想保留两位小数，就 *100）
    temp_int = int(rec["temp"] * 100)
    hum_int  = int(rec["hum"]  * 100)
    # 3) 把 hex hash → bytes32
    data_hash = Web3.to_bytes(hexstr=rec["hash"])
    # 4) 构造交易
    txn = contract.functions.uploadData(
        rec["batch_id"],   # batchId
        unix_ts,
        temp_int,
        hum_int,
        rec["location"],
        rec["productName"],
        data_hash
    ).build_transaction({
        "from":      acct.address,
        "nonce":     w3.eth.get_transaction_count(acct.address),
        "gas":       500_000,
        "gasPrice":  w3.to_wei("20", "gwei"),
    })
    # 5) 签名并发送
    signed = acct.sign_transaction(txn)
    txh = w3.eth.send_raw_transaction(signed.raw_transaction)
    receipt = w3.eth.wait_for_transaction_receipt(txh)
    if receipt.status == 0:
        print("❌ 交易失败，revert 了")
        return
    print(f"✅ 上链完成，txHash={receipt.transactionHash.hex()}")
    print("Chain ID:", w3.eth.chain_id)


if __name__ == "__main__":
    # —— 2. 读取 JSON 文件 ——
    with open("batches/batch321_20250731T020929Z.json", "r", encoding="utf-8") as f:
        data = json.load(f)

    # 如果文件里是一条记录：
    if isinstance(data, dict):
        send_upload(data)
    # 如果是记录列表：
    elif isinstance(data, list):
        for rec in data:
            send_upload(rec)
    else:
        raise ValueError("Unsupported JSON structure")