import os
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv()


class Database:
    def __init__(self):
        self.url = os.getenv("DATABASE_URL")

    def get_connection(self):
        return psycopg2.connect(self.url, cursor_factory=RealDictCursor, sslmode="require")

    def fetch_one(self, sql, params=None):
        conn = self.get_connection()
        try:
            with conn.cursor() as cursor:
                cursor.execute(sql, params)
                return cursor.fetchone()
        finally:
            conn.close()

    def fetch_all(self, sql, params=None):
        conn = self.get_connection()
        try:
            with conn.cursor() as cursor:
                cursor.execute(sql, params)
                return cursor.fetchall()
        finally:
            conn.close()

    def execute(self, sql, params=None, returning=False):
        conn = self.get_connection()
        try:
            with conn.cursor() as cursor:
                cursor.execute(sql, params)
                resultado = cursor.fetchone() if returning else cursor.rowcount
            conn.commit()
            return resultado
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()