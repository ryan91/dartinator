import psycopg2
from psycopg2._psycopg import cursor

t_host = "localhost"
t_port = "5432"
t_dbname = "dartinator"
t_user = "dartinator"
t_pw = "ithrow180s"

def exec_single(cur: cursor, query: str):
    cur.execute(query)
    return cur.fetchone()[0]

class Database:
    def __init__(self):
        self.db_conn = psycopg2.connect(host=t_host, port=t_port,
                dbname=t_dbname, user=t_user, password=t_pw)
    
    def get_cursor(self):
        return self.db_conn.cursor()

    def commit(self):
        self.db_conn.commit()

    def close(self):
        self.db_conn.close()
