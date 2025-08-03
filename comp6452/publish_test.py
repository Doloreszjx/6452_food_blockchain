# publish_test_loop.py
import json
from paho.mqtt.client import Client
import time
import random
from datetime import datetime, timezone, timedelta

client = Client()
client.connect("localhost", 1883)

locations = ['Beijing', 'Hebei', 'Shanghai', 'Guangzhou']

# 起始时间（UTC、去掉微秒）
base_time = datetime.now(timezone.utc).replace(microsecond=0)
# 每条消息间隔 10 分 30 秒
interval = timedelta(minutes=10, seconds=30)

for i in range(4):
    # 循环取 location
    loc = locations[i % len(locations)]
    # 累加时间
    ts_time = base_time + interval * i
    ts = ts_time.isoformat().replace('+00:00', 'Z')
    # 冷链合理温湿度：温度 0–4℃，湿度 70–90%
    temp = round(random.uniform(0.0, 4.0), 1)
    hum = round(random.uniform(70.0, 90.0), 1)

    payload = json.dumps({
        "temp": temp,
        "hum": hum,
        "ts": ts,
        "location": loc,
        "productName": "Beef"
    })
    result = client.publish("coldchain/batch321/sensor", payload)
    print(f"[{i+1}] Published:", payload, "=>", result.rc)
    time.sleep(0.01)  # 可选：短暂休息，防止瞬时过载

client.disconnect()