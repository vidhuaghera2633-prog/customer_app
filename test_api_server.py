from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import urllib.request
import datetime

api_key = "AIzaSyDdXYDkBwTkH93DOLCGqndtTC5us4fnlzU"
project_id = "servicemanagement-saas"
db_url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents"

# Seeding data
dummy_records = [
    {
        "name": "John Smith",
        "email": "john@example.com",
        "mobile": "9876543210",
        "product": "Water Purifier",
        "serial": "WP1001",
        "invoice": "INV1001"
    },
    {
        "name": "Alice Brown",
        "email": "alice@example.com",
        "mobile": "9876543211",
        "product": "Air Conditioner",
        "serial": "AC1002",
        "invoice": "INV1002"
    },
    {
        "name": "David Wilson",
        "email": "david@example.com",
        "mobile": "9876543212",
        "product": "Refrigerator",
        "serial": "RF1003",
        "invoice": "INV1003"
    },
    {
        "name": "Emma Johnson",
        "email": "emma@example.com",
        "mobile": "9876543213",
        "product": "Washing Machine",
        "serial": "WM1004",
        "invoice": "INV1004"
    },
    {
        "name": "Michael Lee",
        "email": "michael@example.com",
        "mobile": "9876543214",
        "product": "Microwave Oven",
        "serial": "MO1005",
        "invoice": "INV1005"
    }
]

def get_auth_token():
    auth_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={api_key}"
    payload = {
        "email": "admin@techserve.com",
        "password": "admin123",
        "returnSecureToken": True
    }
    req = urllib.request.Request(
        auth_url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST"
    )
    with urllib.request.urlopen(req) as response:
        res = json.loads(response.read().decode("utf-8"))
        return res["idToken"], res["localId"]

def write_document(id_token, collection, doc_id, fields):
    url = f"{db_url}/{collection}/{doc_id}"
    data = json.dumps({"fields": fields}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {id_token}"
        },
        method="PATCH"
    )
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode("utf-8"))

def query_customer_by_email(id_token, email):
    url = f"{db_url}:runQuery"
    query = {
        "structuredQuery": {
            "from": [{"collectionId": "customers"}],
            "where": {
                "fieldFilter": {
                    "field": {"fieldPath": "email"},
                    "op": "EQUAL",
                    "value": {"stringValue": email}
                }
            },
            "limit": 1
        }
    }
    data = json.dumps(query).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {id_token}"
        },
        method="POST"
    )
    with urllib.request.urlopen(req) as response:
        res = json.loads(response.read().decode("utf-8"))
        return res

def list_all_customers(id_token):
    url = f"{db_url}/customers"
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {id_token}"
        },
        method="GET"
    )
    with urllib.request.urlopen(req) as response:
        res = json.loads(response.read().decode("utf-8"))
        return res

def run_seeding():
    id_token, uid = get_auth_token()
    
    # 1. Ensure admin_id doc exists
    write_document(id_token, "admin_id", uid, {
        "uid": {"stringValue": uid},
        "name": {"stringValue": "Admin User"},
        "email": {"stringValue": "admin@techserve.com"},
        "role": {"stringValue": "admin"},
        "createdAt": {"timestampValue": datetime.datetime.utcnow().isoformat() + "Z"}
    })
    
    # 2. Customers, Products, Invoices
    for i, rec in enumerate(dummy_records, 1):
        cust_id = f"seed_cust_{i}"
        prod_id = f"seed_prod_{i}"
        inv_id = f"seed_inv_{i}"
        
        write_document(id_token, "customers", cust_id, {
            "id": {"stringValue": cust_id},
            "name": {"stringValue": rec["name"]},
            "email": {"stringValue": rec["email"]},
            "mobile": {"stringValue": rec["mobile"]},
            "createdAt": {"timestampValue": datetime.datetime.utcnow().isoformat() + "Z"}
        })
        
        purchase_date = datetime.datetime.utcnow()
        warranty_end = datetime.datetime(purchase_date.year + 1, purchase_date.month, purchase_date.day)
        
        write_document(id_token, "products", prod_id, {
            "id": {"stringValue": prod_id},
            "customer_id": {"stringValue": cust_id},
            "product_name": {"stringValue": rec["product"]},
            "serial_number": {"stringValue": rec["serial"]},
            "purchase_date": {"timestampValue": purchase_date.isoformat() + "Z"},
            "warranty_end": {"timestampValue": warranty_end.isoformat() + "Z"},
            "createdAt": {"timestampValue": datetime.datetime.utcnow().isoformat() + "Z"}
        })
        
        write_document(id_token, "invoices", inv_id, {
            "id": {"stringValue": inv_id},
            "customer_id": {"stringValue": cust_id},
            "invoice_number": {"stringValue": rec["invoice"]},
            "invoice_date": {"timestampValue": purchase_date.isoformat() + "Z"},
            "createdAt": {"timestampValue": datetime.datetime.utcnow().isoformat() + "Z"}
        })
    return {"status": "success", "message": "Database seeded successfully."}

class RequestHandler(BaseHTTPRequestHandler):
    def _send_response(self, data, status=200):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode("utf-8"))

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        try:
            if self.path == "/seed":
                result = run_seeding()
                self._send_response(result)
            elif self.path == "/customers":
                id_token, _ = get_auth_token()
                result = list_all_customers(id_token)
                self._send_response(result)
            elif self.path.startswith("/customers/"):
                email = self.path.split("/customers/")[-1]
                id_token, _ = get_auth_token()
                result = query_customer_by_email(id_token, email)
                self._send_response(result)
            else:
                self._send_response({"error": "Not Found"}, 404)
        except Exception as e:
            self._send_response({"error": str(e)}, 500)

def run_server(port=8080):
    server_address = ("", port)
    httpd = HTTPServer(server_address, RequestHandler)
    print(f"Starting test API server on port {port}...")
    httpd.serve_forever()

if __name__ == "__main__":
    run_server()
