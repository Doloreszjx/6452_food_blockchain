import mysql.connector
from mysql.connector import errorcode

# 连接配置：改成你自己的 MySQL 用户／密码／主机／端口
cfg = {
    'user':         'appuser',
    'password':     'Secret123',
    'host':         '127.0.0.1',
    'port':         3306,
    'auth_plugin':  'mysql_native_password'
}

DB_NAME = 'coldchain'

TABLES = {}
TABLES['batches'] = (
    "CREATE TABLE IF NOT EXISTS `batches` ("
    "  `batch_id`     VARCHAR(255) NOT NULL,"
    "  `ipfs_cid`     TEXT         NOT NULL,"
    "  `merkle_root`  TEXT         NOT NULL,"
    "  `record_count` INT          NOT NULL,"
    "  `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,"
    "  PRIMARY KEY (`batch_id`)"
    ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
)

def main():
    # 1. 先连上 MySQL（不指定数据库），用于创建新库
    try:
        cnx = mysql.connector.connect(**cfg)
        cursor = cnx.cursor()
        print("Connected to MySQL server.")
    except mysql.connector.Error as err:
        print(f"Error: {err}")
        return

    # 2. 创建数据库
    try:
        cursor.execute(f"CREATE DATABASE IF NOT EXISTS `{DB_NAME}` "
                       "DEFAULT CHARACTER SET utf8mb4")
        print(f"Database `{DB_NAME}` is ready.")
    except mysql.connector.Error as err:
        print(f"Failed creating database: {err}")
        cursor.close()
        cnx.close()
        return

    # 3. 切换到新数据库
    try:
        cnx.database = DB_NAME
    except mysql.connector.Error as err:
        print(f"Database {DB_NAME} does not exist.")
        cursor.close()
        cnx.close()
        return

    # 4. 创建表
    for table_name, ddl in TABLES.items():
        try:
            print(f"Creating table `{table_name}`... ", end='')
            cursor.execute(ddl)
            print("OK")
        except mysql.connector.Error as err:
            if err.errno == errorcode.ER_TABLE_EXISTS_ERROR:
                print("already exists.")
            else:
                print(err.msg)

    # 5. 关闭连接
    cursor.close()
    cnx.close()
    print("Done.")

if __name__ == '__main__':
    main()
