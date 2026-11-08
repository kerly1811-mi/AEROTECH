import datetime
from decimal import Decimal
from flask import Flask, request, jsonify, g, Response
from flask.json.provider import DefaultJSONProvider
from flask_cors import CORS
from werkzeug.exceptions import HTTPException
from database import Database
from seguridad import Seguridad
from vuelos import VueloService
from reservas import ReservaService


class JSONProvider(DefaultJSONProvider):
    ensure_ascii = False

    def default(self, o):
        if isinstance(o, (datetime.date, datetime.time)):
            return o.isoformat()
        if isinstance(o, Decimal):
            return float(o)
        return super().default(o)


app = Flask(__name__)
app.json = JSONProvider(app)
CORS(app)

db = Database()
seguridad = Seguridad(db)
vuelos = VueloService(db)
reservas = ReservaService(db)


@app.route("/")
def inicio():
    return "Servicio AeroTech SOA funcionando"


@app.route("/api/health")
def health():
    total = db.fetch_one("SELECT COUNT(*) AS total FROM vuelos")["total"]
    return {"estado": "ok", "vuelos": total}, 200


@app.route("/api/usuarios/registro", methods=["POST"])
def registro():
    data = request.get_json(silent=True)
    if not data:
        return {"error": "Debe enviar un JSON"}, 400
    if not data.get("nombre") or not data.get("correo") or not data.get("password"):
        return {"error": "nombre, correo y password son obligatorios"}, 400
    if len(data["password"]) < 6:
        return {"error": "La contraseña debe tener mínimo 6 caracteres"}, 400

    correo = data["correo"].strip().lower()
    if db.fetch_one("SELECT id FROM usuarios WHERE correo = %s", (correo,)):
        return {"error": "El correo ya está registrado"}, 409

    nuevo = db.execute("""
        INSERT INTO usuarios (nombre, correo, password_hash, rol_id)
        VALUES (%s, %s, %s, (SELECT id FROM roles WHERE nombre = 'cliente'))
        RETURNING id, nombre, correo
    """, (data["nombre"].strip(), correo, seguridad.hash_password(data["password"])), returning=True)

    return {"mensaje": "Usuario registrado", "usuario": nuevo, "rol": "cliente"}, 201


@app.route("/api/auth/login", methods=["POST"])
def login():
    data = request.get_json(silent=True)
    if not data or not data.get("correo") or not data.get("password"):
        return {"error": "Correo y contraseña son obligatorios"}, 400

    usuario = db.fetch_one("""
        SELECT u.id, u.nombre, u.correo, u.password_hash, u.activo, u.rol_id, r.nombre AS rol
        FROM usuarios u JOIN roles r ON r.id = u.rol_id
        WHERE u.correo = %s
    """, (data["correo"].strip().lower(),))

    if not usuario or not seguridad.verificar_password(data["password"], usuario["password_hash"]):
        return {"error": "Credenciales inválidas"}, 401
    if not usuario["activo"]:
        return {"error": "Usuario desactivado"}, 401

    token, expiracion = seguridad.generar_token(usuario)

    return {
        "mensaje": "Login correcto",
        "token": token,
        "expiracion": expiracion,
        "usuario": {
            "id": usuario["id"],
            "nombre": usuario["nombre"],
            "correo": usuario["correo"],
            "rol": usuario["rol"],
            "permisos": seguridad.obtener_permisos(usuario["rol_id"])
        }
    }, 200


@app.route("/api/auth/logout", methods=["POST"])
@seguridad.token_requerido()
def logout():
    seguridad.revocar_token(g.token)
    return {"mensaje": "Sesión cerrada"}, 200


@app.route("/api/auth/perfil", methods=["GET"])
@seguridad.token_requerido()
def perfil():
    return {
        "id": g.usuario["id"],
        "nombre": g.usuario["nombre"],
        "correo": g.usuario["correo"],
        "rol": g.usuario["rol"],
        "permisos": g.permisos
    }, 200


@app.route("/api/vuelos", methods=["GET"])
@seguridad.token_requerido("vuelos.ver")
def listar_vuelos():
    return vuelos.listar(request.args.get("origen"), request.args.get("destino"), request.args.get("fecha"))


@app.route("/api/vuelos/<int:vuelo_id>", methods=["GET"])
@seguridad.token_requerido("vuelos.ver")
def obtener_vuelo(vuelo_id):
    return vuelos.obtener(vuelo_id)


@app.route("/api/vuelos", methods=["POST"])
@seguridad.token_requerido("vuelos.crear")
def crear_vuelo():
    return vuelos.crear(request.get_json(silent=True))


@app.route("/api/vuelos/<int:vuelo_id>", methods=["PUT"])
@seguridad.token_requerido("vuelos.editar")
def actualizar_vuelo(vuelo_id):
    return vuelos.actualizar(vuelo_id, request.get_json(silent=True))


@app.route("/api/vuelos/<int:vuelo_id>", methods=["DELETE"])
@seguridad.token_requerido("vuelos.eliminar")
def eliminar_vuelo(vuelo_id):
    return vuelos.eliminar(vuelo_id)


@app.route("/api/reservas", methods=["POST"])
@seguridad.token_requerido("reservas.crear")
def crear_reserva():
    return reservas.crear(g.usuario["id"], request.get_json(silent=True))


@app.route("/api/reservas/mis-reservas", methods=["GET"])
@seguridad.token_requerido("reservas.ver_propias")
def mis_reservas():
    return reservas.listar_propias(g.usuario["id"])


@app.route("/api/reservas", methods=["GET"])
@seguridad.token_requerido("reservas.ver_todas")
def todas_reservas():
    return reservas.listar_todas()


@app.route("/api/reservas/<int:reserva_id>", methods=["GET"])
@seguridad.token_requerido()
def obtener_reserva(reserva_id):
    return reservas.obtener(reserva_id, g.usuario, g.permisos)


@app.route("/api/reservas/<int:reserva_id>/cancelar", methods=["PUT"])
@seguridad.token_requerido()
def cancelar_reserva(reserva_id):
    return reservas.cancelar(reserva_id, request.get_json(silent=True), g.usuario, g.permisos)


@app.route("/api/reservas/<int:reserva_id>/comprobante", methods=["GET"])
@seguridad.token_requerido()
def comprobante(reserva_id):
    respuesta, codigo = reservas.comprobante_xml(reserva_id, g.usuario, g.permisos)
    if codigo != 200:
        return respuesta, codigo
    return Response(respuesta, status=200, mimetype="application/xml")


@app.errorhandler(Exception)
def error_general(e):
    if isinstance(e, HTTPException):
        return jsonify({"error": e.description}), e.code
    return jsonify({"error": "Error interno del servidor", "msg": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)