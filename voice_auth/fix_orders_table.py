            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS orders (
                    id BIGSERIAL PRIMARY KEY,
                    product_name TEXT NOT NULL,
                    quantity TEXT NOT NULL,
                    total_price TEXT NOT NULL,
                    status TEXT NOT NULL DEFAULT 'நிலுவையில்',
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
            )
