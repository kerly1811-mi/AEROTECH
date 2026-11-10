import datetime
from decimal import Decimal
from flask import Flask, request, jsonify, g, Response
from flask.json.provider import DefaultJSONProvider
from flask_cors import CORS
from werkzeug.exceptions import HTTPException
from database_service import DatabaseService
from autenticacion_service import AutenticacionService
from usuario_service import UsuarioService
from vuelo_service import VueloService
from asiento_service import AsientoService
from factura_service import FacturaService
from reserva_service import ReservaService


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

db = DatabaseService()
autenticacion_service = AutenticacionService(db)
usuario_service = UsuarioService(db, autenticacion_service)
vuelo_service = VueloService(db)
asiento_service = AsientoService(db)
factura_service = FacturaService()
reserva_service = ReservaService(db, factura_service, asiento_service)


@app.route("/")
def inicio():
    return "API AeroTech funcionando"


@app.route("/api/health")
def health():
    total = db.fetch_one("SELECT COUNT(*) AS total FROM vuelos")["total"]
    return {"estado": "ok", "vuelos": total}, 200


@app.route("/api/usuarios/registro", methods=["POST"])
def registro():
    return usuario_service.registrar(request.get_json(silent=True))


@app.route("/api/usuarios", methods=["GET"])
@autenticacion_service.token_requerido("usuarios.ver")
def listar_usuarios():
    return usuario_service.listar()


@app.route("/api/usuarios/<int:usuario_id>/estado", methods=["PUT"])
@autenticacion_service.token_requerido("usuarios.gestionar")
def cambiar_estado(usuario_id):
    return usuario_service.cambiar_estado(usuario_id, request.get_json(silent=True), g.usuario)


@app.route("/api/auth/login", methods=["POST"])
def login():
    return autenticacion_service.login(request.get_json(silent=True))


@app.route("/api/auth/logout", methods=["POST"])
@autenticacion_service.token_requerido()
def logout():
    return autenticacion_service.logout(g.token)


@app.route("/api/auth/perfil", methods=["GET"])
@autenticacion_service.token_requerido()
def perfil():
    return autenticacion_service.perfil(g.usuario, g.permisos)


@app.route("/api/vuelos", methods=["GET"])
@autenticacion_service.token_requerido("vuelos.ver")
def listar_vuelos():
    return vuelo_service.listar(request.args.get("origen"), request.args.get("destino"), request.args.get("fecha"))


@app.route("/api/vuelos/<int:vuelo_id>", methods=["GET"])
@autenticacion_service.token_requerido("vuelos.ver")
def obtener_vuelo(vuelo_id):
    return vuelo_service.obtener(vuelo_id)


@app.route("/api/vuelos/<int:vuelo_id>/asientos", methods=["GET"])
@autenticacion_service.token_requerido("vuelos.ver")
def mapa_asientos(vuelo_id):
    return asiento_service.mapa(vuelo_id)


@app.route("/api/vuelos", methods=["POST"])
@autenticacion_service.token_requerido("vuelos.crear")
def crear_vuelo():
    return vuelo_service.crear(request.get_json(silent=True))


@app.route("/api/vuelos/<int:vuelo_id>", methods=["PUT"])
@autenticacion_service.token_requerido("vuelos.editar")
def actualizar_vuelo(vuelo_id):
    return vuelo_service.actualizar(vuelo_id, request.get_json(silent=True))


@app.route("/api/vuelos/<int:vuelo_id>", methods=["DELETE"])
@autenticacion_service.token_requerido("vuelos.eliminar")
def eliminar_vuelo(vuelo_id):
    return vuelo_service.eliminar(vuelo_id)


@app.route("/api/reservas", methods=["POST"])
@autenticacion_service.token_requerido("reservas.crear")
def crear_reserva():
    return reserva_service.crear(g.usuario["id"], request.get_json(silent=True))


@app.route("/api/reservas/mis-reservas", methods=["GET"])
@autenticacion_service.token_requerido("reservas.ver_propias")
def mis_reservas():
    return reserva_service.listar_propias(g.usuario["id"])


@app.route("/api/reservas", methods=["GET"])
@autenticacion_service.token_requerido("reservas.ver_todas")
def todas_reservas():
    return reserva_service.listar_todas()


@app.route("/api/reservas/<int:reserva_id>", methods=["GET"])
@autenticacion_service.token_requerido()
def obtener_reserva(reserva_id):
    return reserva_service.obtener(reserva_id, g.usuario, g.permisos)


@app.route("/api/reservas/<int:reserva_id>/cancelar", methods=["PUT"])
@autenticacion_service.token_requerido()
def cancelar_reserva(reserva_id):
    return reserva_service.cancelar(reserva_id, request.get_json(silent=True), g.usuario, g.permisos)


@app.route("/api/reservas/<int:reserva_id>/comprobante", methods=["GET"])
@autenticacion_service.token_requerido()
def comprobante(reserva_id):
    reserva, codigo = reserva_service.obtener(reserva_id, g.usuario, g.permisos)
    if codigo != 200:
        return reserva, codigo
    numero, xml = factura_service.generar_xml(reserva)
    return Response(
        xml,
        status=200,
        mimetype="application/xml",
        headers={"Content-Disposition": f"inline; filename={numero}.xml"}
    )


@app.errorhandler(Exception)
def error_general(e):
    if isinstance(e, HTTPException):
        return jsonify({"error": e.description}), e.code
    return jsonify({"error": "Error interno del servidor", "msg": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
