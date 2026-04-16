from __future__ import annotations

import os
from dataclasses import asdict, dataclass
from typing import Any

import numpy as np
import psycopg2
from psycopg2 import sql
from psycopg2.extras import RealDictCursor

DEFAULT_DB_NAME = "uzhavartrade_voiceauth"


@dataclass(frozen=True)
class SellerRecord:
    id: int
    name: str
    phone: str
    created_at: str
    last_login: str | None
    upi_id: str | None


@dataclass(frozen=True)
class LoginAttemptRecord:
    id: int
    seller_id: int | None
    phone_input: str | None
    similarity: float
    success: bool
    used_otp: bool
    created_at: str


def _connection_kwargs() -> dict[str, Any]:
    database_url = os.getenv("DATABASE_URL", "").strip()
    if database_url:
        return {"dsn": database_url, "cursor_factory": RealDictCursor}

    kwargs: dict[str, Any] = {
        "host": os.getenv("PGHOST", "localhost"),
        "port": int(os.getenv("PGPORT", "5432")),
        "dbname": os.getenv("PGDATABASE", DEFAULT_DB_NAME),
        "user": os.getenv("PGUSER", "postgres"),
        "cursor_factory": RealDictCursor,
    }
    password = os.getenv("PGPASSWORD", "")
    if password:
        kwargs["password"] = password
    return kwargs


def _create_database_if_missing() -> None:
    database_url = os.getenv("DATABASE_URL", "").strip()
    if database_url:
        # Cannot safely infer maintenance DB details from an arbitrary DSN.
        return

    target_db = os.getenv("PGDATABASE", DEFAULT_DB_NAME)
    maintenance_kwargs = {
        "host": os.getenv("PGHOST", "localhost"),
        "port": int(os.getenv("PGPORT", "5432")),
        "dbname": "postgres",
        "user": os.getenv("PGUSER", "postgres"),
    }
    password = os.getenv("PGPASSWORD", "")
    if password:
        maintenance_kwargs["password"] = password

    conn = psycopg2.connect(**maintenance_kwargs)
    try:
        conn.autocommit = True
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT 1 FROM pg_database WHERE datname = %s",
                (target_db,),
            )
            exists = cursor.fetchone() is not None
            if not exists:
                cursor.execute(
                    sql.SQL("CREATE DATABASE {}")
                    .format(sql.Identifier(target_db))
                )
    finally:
        conn.close()


def get_connection() -> psycopg2.extensions.connection:
    kwargs = _connection_kwargs()
    try:
        return psycopg2.connect(**kwargs)
    except psycopg2.OperationalError as exc:
        message = str(exc).lower()
        if "does not exist" in message and "database" in message:
            _create_database_if_missing()
            return psycopg2.connect(**kwargs)
        raise RuntimeError(
            "Could not connect to PostgreSQL. Set DATABASE_URL or PGHOST/PGPORT/PGDATABASE/PGUSER/PGPASSWORD correctly."
        ) from exc


def init_db() -> None:
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS sellers (
                id BIGSERIAL PRIMARY KEY,
                name TEXT NOT NULL,
                phone TEXT NOT NULL UNIQUE,
                voice_embedding BYTEA NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                last_login TIMESTAMPTZ,
                upi_id TEXT
            )
            """
        )
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS login_attempts (
                    id BIGSERIAL PRIMARY KEY,
                    seller_id BIGINT REFERENCES sellers(id) ON DELETE SET NULL,
                    phone_input TEXT,
                    similarity REAL,
                    success BOOLEAN NOT NULL,
                    used_otp BOOLEAN NOT NULL DEFAULT FALSE,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
            )
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS orders (
                    id BIGSERIAL PRIMARY KEY,
                    product_name TEXT NOT NULL,
                    quantity TEXT NOT NULL,
                    total_price TEXT NOT NULL,
                    per_kg_price TEXT,
                    buyer_name TEXT,
                    status TEXT NOT NULL DEFAULT 'நிலுவையில்',
                    seller_name TEXT,
                    seller_upi_id TEXT,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
            )
            cursor.execute(
                """
                ALTER TABLE orders ADD COLUMN IF NOT EXISTS per_kg_price TEXT;
                ALTER TABLE orders ADD COLUMN IF NOT EXISTS buyer_name TEXT;
                """
            )
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS products (
                    id BIGSERIAL PRIMARY KEY,
                    name TEXT NOT NULL,
                    weight TEXT NOT NULL,
                    per_kg_price TEXT NOT NULL,
                    total_price TEXT NOT NULL,
                    price TEXT NOT NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
            )
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_sellers_phone ON sellers(phone)")
            cursor.execute(
                "CREATE INDEX IF NOT EXISTS idx_login_attempts_created_at ON login_attempts(created_at)"
            )
        conn.commit()
    finally:
        conn.close()


def _normalize_phone(phone: str) -> str:
    return "".join(ch for ch in phone if ch.isdigit())


def add_seller(name: str, phone: str, embedding: np.ndarray) -> int:
    normalized_phone = _normalize_phone(phone)
    if not normalized_phone:
        raise ValueError("Phone number must contain digits.")

    embedding_blob = np.asarray(embedding, dtype=np.float32).tobytes()
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
            """
            INSERT INTO sellers (name, phone, voice_embedding)
            VALUES (%s, %s, %s)
            RETURNING id
            """,
            (name, normalized_phone, psycopg2.Binary(embedding_blob)),
        )
            row = cursor.fetchone()
        conn.commit()
        if not row:
            raise RuntimeError("Failed to insert seller.")
        return int(row["id"])
    finally:
        conn.close()


def get_seller_by_phone(phone: str) -> SellerRecord | None:
    normalized_phone = _normalize_phone(phone)
    if not normalized_phone:
        return None

    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
            """
            SELECT id, name, phone, created_at, last_login
            FROM sellers
            WHERE phone = %s
            """,
            (normalized_phone,),
            )
            row = cursor.fetchone()
    finally:
        conn.close()

    if not row:
        return None

    return SellerRecord(
        id=int(row["id"]),
        name=row["name"],
        phone=row["phone"],
        created_at=row["created_at"],
        last_login=row["last_login"],
    )


def get_sellers_for_matching() -> list[dict[str, Any]]:
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id, name, phone, voice_embedding FROM sellers")
            rows = cursor.fetchall()
    finally:
        conn.close()

    sellers: list[dict[str, Any]] = []
    for row in rows:
        sellers.append(
            {
                "id": int(row["id"]),
                "name": row["name"],
                "phone": row["phone"],
                "embedding": np.frombuffer(bytes(row["voice_embedding"]), dtype=np.float32),
            }
        )
    return sellers


def mark_successful_login(seller_id: int) -> str:
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "UPDATE sellers SET last_login = NOW() WHERE id = %s RETURNING last_login",
                (seller_id,),
            )
            timestamp_row = cursor.fetchone()
        conn.commit()
    finally:
        conn.close()
    return str(timestamp_row["last_login"]) if timestamp_row else ""


def log_login_attempt(
    seller_id: int | None,
    phone_input: str | None,
    similarity: float,
    success: bool,
    used_otp: bool,
) -> None:
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
            """
            INSERT INTO login_attempts (seller_id, phone_input, similarity, success, used_otp)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (
                seller_id,
                phone_input,
                float(similarity),
                bool(success),
                bool(used_otp),
            ),
        )
        conn.commit()
    finally:
        conn.close()


def list_sellers() -> list[dict[str, Any]]:
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
            """
            SELECT id, name, phone, created_at, last_login, upi_id
            FROM sellers
            ORDER BY id DESC
            """
            )
            rows = cursor.fetchall()
    finally:
        conn.close()

    sellers = [
        SellerRecord(
            id=int(row["id"]),
            name=row["name"],
            phone=row["phone"],
            created_at=row["created_at"],
            last_login=row["last_login"],
            upi_id=row["upi_id"],
        )
        for row in rows
    ]
    return [asdict(seller) for seller in sellers]


def list_login_attempts(limit: int = 50) -> list[dict[str, Any]]:
    if limit <= 0:
        return []

    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
            """
            SELECT id, seller_id, phone_input, similarity, success, used_otp, created_at
            FROM login_attempts
            ORDER BY id DESC
            LIMIT %s
            """,
            (int(limit),),
            )
            rows = cursor.fetchall()
    finally:
        conn.close()

    attempts = [
        LoginAttemptRecord(
            id=int(row["id"]),
            seller_id=int(row["seller_id"]) if row["seller_id"] is not None else None,
            phone_input=row["phone_input"],
            similarity=float(row["similarity"]),
            success=bool(row["success"]),
            used_otp=bool(row["used_otp"]),
            created_at=row["created_at"],
        )
        for row in rows
    ]
    return [asdict(attempt) for attempt in attempts]
