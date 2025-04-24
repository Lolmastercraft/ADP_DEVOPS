from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from dotenv import load_dotenv
import boto3
import bcrypt
import os

load_dotenv()

app = Flask(__name__, static_folder="public")
CORS(app)

# Configuración AWS
AWS_REGION = os.getenv("AWS_REGION")
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
AWS_SESSION_TOKEN = os.getenv("AWS_SESSION_TOKEN")
PORT = int(os.getenv("PORT", 5000))

dynamodb = boto3.resource("dynamodb",
    region_name=AWS_REGION,
    aws_access_key_id=AWS_ACCESS_KEY_ID,
    aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
    aws_session_token=AWS_SESSION_TOKEN
)

table = dynamodb.Table("Users")

@app.route("/")
def index():
    return send_from_directory("public", "index.html")

@app.route("/<path:path>")
def static_proxy(path):
    return send_from_directory("public", path)

@app.post("/users")
def register_user():
    data = request.json
    if not all(k in data for k in ("email", "username", "password")):
        return jsonify(error="Faltan campos obligatorios."), 400
    hashed_pw = bcrypt.hashpw(data["password"].encode(), bcrypt.gensalt()).decode()
    item = {
        "email": data["email"],
        "username": data["username"],
        "password": hashed_pw
    }
    try:
        table.put_item(Item=item)
        return jsonify(message="Usuario creado con éxito.")
    except Exception as e:
        return jsonify(error=str(e)), 500

@app.post("/login")
def login_user():
    data = request.json
    if not all(k in data for k in ("email", "password")):
        return jsonify(error="Faltan datos."), 400
    try:
        resp = table.get_item(Key={"email": data["email"]})
        user = resp.get("Item")
        if user and bcrypt.checkpw(data["password"].encode(), user["password"].encode()):
            return jsonify(message="Inicio de sesión exitoso.")
        else:
            return jsonify(error="Credenciales inválidas."), 401
    except Exception as e:
        return jsonify(error=str(e)), 500

@app.get("/users")
def list_users():
    try:
        data = table.scan()
        return jsonify(data.get("Items", []))
    except Exception as e:
        return jsonify(error=str(e)), 500

@app.get("/users/<email>")
def get_user(email):
    try:
        resp = table.get_item(Key={"email": email})
        user = resp.get("Item")
        if user:
            return jsonify(user)
        return jsonify(error="Usuario no encontrado."), 404
    except Exception as e:
        return jsonify(error=str(e)), 500

@app.put("/users/<email>")
def update_user(email):
    data = request.json
    update_expr = []
    expr_attr = {}
    if "username" in data:
        update_expr.append("username = :u")
        expr_attr[":u"] = data["username"]
    if "password" in data:
        hashed_pw = bcrypt.hashpw(data["password"].encode(), bcrypt.gensalt()).decode()
        update_expr.append("password = :p")
        expr_attr[":p"] = hashed_pw
    if not update_expr:
        return jsonify(error="Nada para actualizar."), 400
    try:
        table.update_item(
            Key={"email": email},
            UpdateExpression="SET " + ", ".join(update_expr),
            ExpressionAttributeValues=expr_attr
        )
        return jsonify(message="Usuario actualizado.")
    except Exception as e:
        return jsonify(error=str(e)), 500

@app.delete("/users/<email>")
def delete_user(email):
    try:
        table.delete_item(Key={"email": email})
        return jsonify(message="Usuario eliminado.")
    except Exception as e:
        return jsonify(error=str(e)), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PORT, debug=True)
