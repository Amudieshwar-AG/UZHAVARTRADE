import psycopg2
from models import _connection_kwargs

# Use the exported kwargs from models.py
conn = psycopg2.connect(**_connection_kwargs())
cursor = conn.cursor()

REAL_UPI_ID = "siddarthmariappan@okicici" # <--- PUT YOUR REAL UPI ID HERE
NEW_NAME = "Siddartha Mariappan"                   # <--- PUT YOUR NAME HERE

# This updates the very first seller in your database
cursor.execute("""
    UPDATE sellers 
    SET upi_id = %s, name = %s 
    WHERE phone = '9360604455' OR id = (SELECT id FROM sellers LIMIT 1)
""", (REAL_UPI_ID, NEW_NAME))

conn.commit()
cursor.close()
conn.close()

print(f"Successfully updated Seller UPI ID to: {REAL_UPI_ID}")