import os, json, time, hashlib
from collections import defaultdict
from datetime import datetime
import pika

# 配置
RABBITMQ_URL = 'amqp://guest:guest@localhost:5672/'
RAW_EXCHANGE = 'raw_data'
BATCH_DIR   = './batches'
# 每批次最大消息数，或可改为“每 5 分钟打包一次”
MAX_PER_BATCH = 4

# 保持各 batch 的缓存
batch_cache = defaultdict(list)

def calc_sha256(record: dict) -> str:
    raw = json.dumps(record, sort_keys=True).encode('utf-8')
    return hashlib.sha256(raw).hexdigest()

def try_flush_batch(batch_id: str):
    """当缓存量够或定时到达，就写文件并清空缓存"""
    records = batch_cache[batch_id]
    if len(records) >= MAX_PER_BATCH:
        timestamp = datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')
        filename = f'{batch_id}_{timestamp}.json'
        os.makedirs(BATCH_DIR, exist_ok=True)
        path = os.path.join(BATCH_DIR, filename)

        # 写入文件
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(records, f, indent=2)
        print(f'[Batch Written] {path} ({len(records)} records)')

        # 清空缓存
        batch_cache[batch_id].clear()

def on_message(ch, method, properties, body):
    try:
        payload = json.loads(body)
        routing_key = method.routing_key  # e.g. coldchain/batch123/sensor
        # 解析 batch_id
        batch_id = routing_key.split('/')[1]

        # 深度校验
        if not isinstance(payload.get('temp'), (int, float)):
            return ch.basic_ack(delivery_tag=method.delivery_tag)
        if not isinstance(payload.get('hum'), (int, float)):
            return ch.basic_ack(delivery_tag=method.delivery_tag)
        # 时间戳可加更严格校验...

        # 计算哈希并加入记录
        record = {
            'batch_id': batch_id,
            'ts': payload['ts'],
            'temp': payload['temp'],
            'hum': payload['hum'],
            'location': payload['location'],
            'productName': payload['productName'],
            'hash': calc_sha256(payload)
        }
        batch_cache[batch_id].append(record)

        # 条件满足则打包
        try_flush_batch(batch_id)

        # 确认消息
        ch.basic_ack(delivery_tag=method.delivery_tag)
    except Exception as e:
        print('Cleaner error:', e)
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)

def main():
    params = pika.URLParameters(RABBITMQ_URL)
    conn = pika.BlockingConnection(params)
    channel = conn.channel()
    channel.exchange_declare(exchange=RAW_EXCHANGE, exchange_type='topic', durable=True)

    # 创建一个匿名队列并绑定
    result = channel.queue_declare('', exclusive=True)
    queue_name = result.method.queue
    channel.queue_bind(exchange=RAW_EXCHANGE, queue=queue_name, routing_key='#')

    channel.basic_qos(prefetch_count=10)
    channel.basic_consume(queue=queue_name, on_message_callback=on_message)

    print('Data Cleaner waiting for messages...')
    channel.start_consuming()

if __name__ == '__main__':
    main()
