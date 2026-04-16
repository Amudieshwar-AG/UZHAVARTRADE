import os, sys
sys.path.insert(0, os.path.abspath('voice_auth'))
import models
conn = models.get_connection()
conn.autocommit = True
cur = conn.cursor()
try: cur.execute('ALTER TABLE sellers ADD COLUMN upi_id TEXT;')
except Exception as e: print('1', e)
try: cur.execute('ALTER TABLE orders ADD COLUMN seller_name TEXT;')
except Exception as e: print('2', e)
try: cur.execute('ALTER TABLE orders ADD COLUMN seller_upi_id TEXT;')
except Exception as e: print('3', e)
try: cur.execute("UPDATE sellers SET upi_id = LOWER(REPLACE(name, ' ', '')) || '@okaxis' WHERE upi_id IS NULL;")
except Exception as e: print('4', e)
