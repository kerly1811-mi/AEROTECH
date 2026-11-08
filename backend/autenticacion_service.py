import os
import datetime
import jwt
from functools import wraps
from flask import request, jsonify, g
from werkzeug.security import generate_password_hash, check_password_hash


class AutenticacionService:
    def __init__(self, db):
        self.db = db
        self.secret = os.getenv("JWT_SECRET")
        self.exp_minutos = int(os.getenv("JWT_EXP_MINUTOS", 30))

    def hash_password(self, password):
        return generate_password_hash(password, method="pbkdf2:sha256")

    def verificar_password(self, password, password_hash):
        return check_password_hash(password_hash, password)

    def obtener_permisos(self, rol_id):
        filas = self.db.fetch_all("""
            SELECT p.codigo FROM rol_permisos rp
            JOIN permisos p ON p.id = rp.permiso_id
            WHERE rp.rol_id = %s
        """, (rol_id,))
        return [f["codigo"] for f in filas]

    def generar_token(self, usuario):
        expiracion = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(minutes=self.exp_minutos)
        token = jwt.encode(
            {"sub": str(usuario["id"]), "rol": usuario["rol"], "exp": expiracion},
            self.secret,
            algorithm="HS256"
        )
        self.db.execute("""
            INSERT INTO tokens (usuario_id, token, expiracion, estado)
            VALUES (%s, %s, %s, 'activo')
        """, (usuario["id"], token, expiracion))
        return token, expiracion

    def revocar_token(self, token):
        self.db.execute("UPDATE tokens SET estado = 'revocado' WHERE token = %s", (token,))

    def login(self, data):
        if not data or not data.get("correo") or not data.get("password"):
            return {"error": "Correo y contraseña son obligatorios"}, 400

        usuario = self.db.fetch_one("""
            SELECT u.id, u.nombre, u.correo, u.password_hash, u.activo, u.rol_id, r.nombre AS rol
            FROM usuarios u JOIN roles r ON r.id = u.rol_id
            WHERE u.correo = %s
        """, (data["correo"].strip().lower(),))

        if not usuario or not self.verificar_password(data["password"], usuario["password_hash"]):
            return {"error": "Credenciales inválidas"}, 401
        if not usuario["activo"]:
            return {"error": "Usuario desactivado"}, 401

        token, expiracion = self.generar_token(usuario)
        return {
            "mensaje": "Login correcto",
            "token": token,
            "expiracion": expiracion,
            "usuario": {
                "id": usuario["id"],
                "nombre": usuario["nombre"],
                "correo": usuario["correo"],
                "rol": usuario["rol"],
                "permisos": self.obtener_permisos(usuario["rol_id"])
            }
        }, 200

    def logout(self, token):
        self.revocar_token(token)
        return {"mensaje": "Sesión cerrada"}, 200

    def perfil(self, usuario, permisos):
        return {
            "id": usuario["id"],
            "nombre": usuario["nombre"],
            "correo": usuario["correo"],
            "rol": usuario["rol"],
            "permisos": permisos
        }, 200

    def token_requerido(self, permiso=None):
        def decorador(f):
            @wraps(f)
            def wrapper(*args, **kwargs):
                auth = request.headers.get("Authorization", "")
                if not auth.startswith("Bearer "):
                    return jsonify({"error": "Token no enviado"}), 401
                token = auth.replace("Bearer ", "", 1)

                try:
                    jwt.decode(token, self.secret, algorithms=["HS256"])
                except jwt.ExpiredSignatureError:
                    self.revocar_token(token)
                    return jsonify({"error": "Token expirado"}), 401
                except jwt.InvalidTokenError:
                    return jsonify({"error": "Token inválido"}), 401

                usuario = self.db.fetch_one("""
                    SELECT u.id, u.nombre, u.correo, u.activo, u.rol_id, r.nombre AS rol
                    FROM tokens t
                    JOIN usuarios u ON u.id = t.usuario_id
                    JOIN roles r ON r.id = u.rol_id
                    WHERE t.token = %s AND t.estado = 'activo' AND t.expiracion > NOW()
                """, (token,))

                if not usuario:
                    return jsonify({"error": "Token revocado o expirado"}), 401
                if not usuario["activo"]:
                    return jsonify({"error": "Usuario desactivado"}), 401

                permisos = self.obtener_permisos(usuario["rol_id"])
                if permiso and permiso not in permisos:
                    return jsonify({"error": "No tiene permiso para esta acción"}), 403

                g.usuario = usuario
                g.permisos = permisos
                g.token = token
                return f(*args, **kwargs)
            return wrapper
        return decorador