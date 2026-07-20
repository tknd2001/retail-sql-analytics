"""
Generates a small synthetic retail dataset for the AWS Serverless SQL
Analytics project. Run it locally. Output CSVs are meant
to be uploaded to your own private S3 bucket.

Usage:
    pip install faker
    python generate_data.py

Output (in ./data/):
    customers.csv    ~500 rows
    products.csv     ~80 rows
    orders.csv       ~3,000 rows
    order_items.csv  ~7,500-9,000 rows

Total size is a few MB -- cheap to store, cheap to query, fast to load.
"""

import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

from faker import Faker

fake = Faker()
Faker.seed(42)
random.seed(42)

OUT_DIR = Path(__file__).resolve().parent.parent / "data"
OUT_DIR.mkdir(exist_ok=True)

N_CUSTOMERS = 500
N_PRODUCTS = 80
N_ORDERS = 3000
CATEGORIES = ["Electronics", "Home & Kitchen", "Apparel", "Books", "Sports", "Beauty"]
START_DATE = datetime(2023, 1, 1)
END_DATE = datetime(2025, 12, 31)


def random_date(start, end):
    delta = end - start
    return start + timedelta(days=random.randint(0, delta.days))


def gen_customers():
    rows = []
    for cid in range(1, N_CUSTOMERS + 1):
        signup = random_date(START_DATE, END_DATE - timedelta(days=1))
        rows.append({
            "customer_id": cid,
            "first_name": fake.first_name(),
            "last_name": fake.last_name(),
            "email": fake.unique.email(),
            "city": fake.city(),
            "country": fake.country(),
            "signup_date": signup.date().isoformat(),
        })
    return rows


def gen_products():
    rows = []
    for pid in range(1, N_PRODUCTS + 1):
        category = random.choice(CATEGORIES)
        rows.append({
            "product_id": pid,
            "product_name": fake.unique.catch_phrase(),
            "category": category,
            "unit_price": round(random.uniform(5, 500), 2),
        })
    return rows


def gen_orders_and_items(customers, products):
    orders, items = [], []
    item_id = 1
    for oid in range(1, N_ORDERS + 1):
        customer = random.choice(customers)
        signup = datetime.fromisoformat(customer["signup_date"])
        order_date = random_date(max(signup, START_DATE), END_DATE)
        status = random.choices(
            ["completed", "completed", "completed", "cancelled", "returned"],
            weights=[70, 10, 10, 5, 5],
        )[0]
        orders.append({
            "order_id": oid,
            "customer_id": customer["customer_id"],
            "order_date": order_date.date().isoformat(),
            "status": status,
        })

        n_items = random.randint(1, 5)
        chosen = random.sample(products, n_items)
        for product in chosen:
            qty = random.randint(1, 4)
            items.append({
                "order_item_id": item_id,
                "order_id": oid,
                "product_id": product["product_id"],
                "quantity": qty,
                "unit_price": product["unit_price"],
            })
            item_id += 1
    return orders, items


def write_csv(path, rows):
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    print(f"wrote {len(rows):>6} rows -> {path}")


if __name__ == "__main__":
    customers = gen_customers()
    products = gen_products()
    orders, items = gen_orders_and_items(customers, products)

    write_csv(OUT_DIR / "customers.csv", customers)
    write_csv(OUT_DIR / "products.csv", products)
    write_csv(OUT_DIR / "orders.csv", orders)
    write_csv(OUT_DIR / "order_items.csv", items)

    print("\nDone. Upload the data/ folder to your own private S3 bucket, e.g.:")
    print("  aws s3 cp data/ s3://<your-bucket-name>/retail/ --recursive")
