#!/usr/bin/env python3
# get_trace_history.py

import os
import json
import datetime
from web3 import Web3
from dotenv import load_dotenv

def main():
    # 1. 加载环境变量
    load_dotenv()  # pip install python-dotenv
    RPC_URL         = os.getenv("WEB3_RPC_URL")
    CONTRACT_ADDR   = os.getenv("CONTRACT_ADDRESS")
    ABI_PATH        = os.getenv("ABI_PATH")

    if not (RPC_URL and CONTRACT_ADDR and ABI_PATH):
        raise RuntimeError("请先在 .env 文件中配置 WEB3_RPC_URL, CONTRACT_ADDRESS, ABI_PATH")

    # 2. 连接到以太网络
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    if not w3.is_connected():
        raise RuntimeError(f"无法连接到 RPC：{RPC_URL}")

    # 3. 加载合约 ABI
    with open(ABI_PATH, 'r', encoding='utf-8') as f:
        abi = json.load(f)

    # 4. 实例化合约
    contract = w3.eth.contract(
        address=w3.to_checksum_address(CONTRACT_ADDR),
        abi=abi
    )

    # 5. 调用 getTraceHistory
    product_id = "batch321"
    tss, temps, hums, locations, product_names, data_hashes = \
        contract.functions.getTraceHistory(product_id).call()

    # 6. 打印结果
    print(f"====== TraceHistory for {product_id} ======")
    # 确保它们长度一致
    n = len(tss)
    print(f"共 {n} 条记录\n")
    for i in range(n):
        ts = tss[i]
        try:
            dt = datetime.datetime.fromtimestamp(ts)
            ts_str = dt.strftime("%Y-%m-%d %H:%M:%S")
        except:
            ts_str = str(ts)
        temp = temps[i]
        hum  = hums[i]
        loc  = locations[i]
        name = product_names[i]
        dh   = data_hashes[i].hex()

        print(f"记录 {i+1}:")
        print(f"  时间戳: {ts} ({ts_str})")
        print(f"  温度: {temp/100}℃")
        print(f"  湿度: {hum/100}")
        print(f"  位置: {loc}")
        print(f"  产品名称: {name}")
        print(f"  数据哈希: {dh}")
        print("-" * 40)

if __name__ == "__main__":
    main()
