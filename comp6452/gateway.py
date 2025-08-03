import json
import pika
from paho.mqtt.client import Client, MQTTv311

# RabbitMQ 连接参数
RABBITMQ_URL = 'amqp://guest:guest@localhost:5672/'
EXCHANGE = 'raw_data'

# MQTT 回调：收到消息时触发
def on_message(client, userdata, msg):
    raw = msg.payload.decode().strip()
    print(f"[DEBUG] 收到原始 payload: [{raw}]，topic = {msg.topic}")

    # 如果首尾是额外的单引号或双引号，先剥掉
    if (raw.startswith("'") and raw.endswith("'")) or \
            (raw.startswith('"') and raw.endswith('"')):
        raw = raw[1:-1].strip()
        # print(raw)
        print(f"[DEBUG] 剥除外层引号后: [{raw!r}]")


    if not raw:
        print("  → payload 为空，已跳过。")
        return

    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as e:
        print("  → JSON 解析失败，跳过：", e)
        return

    # payload = raw

    # 简单校验
    if all(k in payload for k in ("temp", "hum", "ts")):
        channel.basic_publish(
            exchange=EXCHANGE,
            routing_key=msg.topic,
            body=json.dumps(payload)
        )
        print(f"  → 转发成功: {payload}")
    else:
        print("  → 字段校验失败，已丢弃:", payload)


if __name__ == '__main__':
    # 1. 建立 RabbitMQ 连接
    params = pika.URLParameters(RABBITMQ_URL)
    connection = pika.BlockingConnection(params)
    channel = connection.channel()
    channel.exchange_declare(exchange=EXCHANGE, exchange_type='topic', durable=True)

    # 2. 建立 MQTT 客户端并订阅
    mqtt_client = Client(protocol=MQTTv311)
    mqtt_client.on_message = on_message
    mqtt_client.connect('localhost', 1883)
    mqtt_client.subscribe('coldchain/+/sensor')
    print("Gateway listening on MQTT topic 'coldchain/+/sensor'...")

    # 3. 开始循环，持续接收并转发
    mqtt_client.loop_forever()
